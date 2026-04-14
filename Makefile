.DEFAULT_GOAL := help
SHELL := /bin/bash
export PATH := $(HOME)/.local/bin:$(PATH)

APP_NAME    := gradle-java-fips-test
GRADLE      := ./gradlew
NO_CACHE    := --no-configuration-cache

# All binary tools (java, node, hadolint, act, gitleaks, trivy) are pinned in
# .mise.toml and installed via `mise install` (see deps-install). Gradle comes
# from the wrapper. Only JAR and Docker-image versions live here.

# renovate: datasource=github-releases depName=google/google-java-format extractVersion=^v(?<version>.*)$
GJF_VERSION := 1.28.0
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.12.0

CURRENTTAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

GJF_JAR := $(HOME)/.cache/google-java-format/google-java-format-$(GJF_VERSION)-all-deps.jar
GJF_URL := https://github.com/google/google-java-format/releases/download/v$(GJF_VERSION)/google-java-format-$(GJF_VERSION)-all-deps.jar

DOCKER_IMAGE      := $(APP_NAME)
DOCKER_REGISTRY   ?= docker.io
DOCKER_REPO       ?= $(shell whoami)/$(DOCKER_IMAGE)
DOCKER_TAG        ?= latest
DOCKER_FULL_IMAGE := $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(DOCKER_TAG)

OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

#help: @ List available tasks
help:
	@echo -e "Usage: make COMMAND\n\nCommands :\n"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-20s\033[0m - %s\n", $$1, $$2}'

#deps: @ Verify required build dependencies are available
deps:
	@command -v curl >/dev/null 2>&1 || { echo "Error: curl required."; exit 1; }
	@java -version 2>&1 | grep -q "\"21\." || { echo "Error: Java 21 required. Run: make deps-install"; exit 1; }
	@[ -x "$(GRADLE)" ] || { echo "Error: Gradle wrapper (gradlew) not found. Run: make deps-install"; exit 1; }

#deps-install: @ Install all toolchain dependencies via mise (reads .mise.toml)
deps-install:
	@command -v mise >/dev/null 2>&1 || { echo "Installing mise..."; curl -fsSL https://mise.run | sh; }
	@mise install
	@echo "Done. Ensure 'mise activate' is in your shell rc, or run: eval \"\$$(mise activate bash)\""

#deps-check: @ Show required tools and installation status
deps-check:
	@echo "--- Tool status ---"
	@for tool in java mise docker hadolint gitleaks trivy act node; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done

#clean: @ Clean build artifacts
clean:
	@$(GRADLE) clean && rm -rf build app/build

#build: @ Build project (compile only, no tests)
build: deps
	@$(GRADLE) build -x test

$(GJF_JAR):
	@mkdir -p $(dir $(GJF_JAR))
	@curl -sSfL -o $(GJF_JAR) $(GJF_URL)

#format: @ Auto-format Java source code (google-java-format)
format: $(GJF_JAR)
	@find app/src -name '*.java' -type f | \
		xargs java --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
			-jar $(GJF_JAR) --replace

#format-check: @ Verify code formatting (CI gate)
format-check: $(GJF_JAR)
	@find app/src -name '*.java' -type f | \
		xargs java --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
			-jar $(GJF_JAR) --set-exit-if-changed --dry-run > /dev/null

#lint: @ Run Java code style checks (Checkstyle) and Dockerfile lint
lint: deps deps-hadolint
	@$(GRADLE) checkstyleMain checkstyleTest
	@hadolint Dockerfile

#deps-gitleaks: @ Ensure gitleaks is installed (via mise)
deps-gitleaks:
	@command -v gitleaks >/dev/null 2>&1 || { \
		command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }; \
		mise install gitleaks; \
	}

#secrets: @ Scan for hardcoded secrets with gitleaks
secrets: deps-gitleaks
	@gitleaks detect --source . --verbose --redact --no-banner

#deps-trivy: @ Ensure Trivy is installed (via mise)
deps-trivy:
	@command -v trivy >/dev/null 2>&1 || { \
		command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }; \
		mise install trivy; \
	}

#trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
trivy-fs: deps-trivy
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH --exit-code 1 .

#mermaid-lint: @ Validate Mermaid diagrams in markdown files
mermaid-lint:
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for mermaid-lint"; exit 1; }
	@set -euo pipefail; \
	MD_FILES=$$(grep -lF '```mermaid' README.md CLAUDE.md 2>/dev/null || true); \
	if [ -z "$$MD_FILES" ]; then \
		echo "No Mermaid blocks found — skipping."; \
		exit 0; \
	fi; \
	FAILED=0; \
	for md in $$MD_FILES; do \
		echo "Validating Mermaid blocks in $$md..."; \
		LOG=$$(mktemp); \
		if docker run --rm -v "$$PWD:/data" \
			minlag/mermaid-cli:$(MERMAID_CLI_VERSION) \
			-i "/data/$$md" -o "/tmp/$$(basename $$md .md).svg" >"$$LOG" 2>&1; then \
			echo "  ✓ All blocks rendered cleanly."; \
		else \
			echo "  ✗ Parse error in $$md:"; sed 's/^/    /' "$$LOG"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
		rm -f "$$LOG"; \
	done; \
	if [ "$$FAILED" -gt 0 ]; then echo "Mermaid lint: $$FAILED file(s) had parse errors."; exit 1; fi

#static-check: @ Composite quality gate (format-check + lint + secrets + trivy-fs + mermaid-lint)
static-check: format-check lint secrets trivy-fs mermaid-lint
	@echo "Static check passed."

#test: @ Run FIPS validator tests (FIPSValidatorTest only)
test: deps
	@$(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3

#integration-test: @ Run integration tests (spawn-JVM subprocess IT suite)
integration-test: deps
	@$(GRADLE) :app:integrationTest

#run: @ Run project
run: deps
	@$(GRADLE) :app:run $(NO_CACHE) --warning-mode all

#cve-check: @ Run OWASP dependency vulnerability scan (needs NVD_API_KEY)
cve-check: deps
	@[ -n "$${NVD_API_KEY:-}" ] || echo "Warning: NVD_API_KEY not set"
	@$(GRADLE) :app:securityScan $(NO_CACHE) --warning-mode all \
		$$([ -n "$${NVD_API_KEY:-}" ] && echo "-PnvdApiKey=$$NVD_API_KEY") \
		$$([ -n "$${OSS_INDEX_USER:-}" ] && echo "-PossIndexUser=$$OSS_INDEX_USER") \
		$$([ -n "$${OSS_INDEX_TOKEN:-}" ] && echo "-PossIndexToken=$$OSS_INDEX_TOKEN")

#cve-db-update: @ Update vulnerability database manually
cve-db-update: deps
	@$(GRADLE) dependencyCheckUpdate $(NO_CACHE)

#cve-db-purge: @ Purge local database (forces fresh download)
cve-db-purge: deps
	@$(GRADLE) dependencyCheckPurge $(NO_CACHE)

#coverage-generate: @ Run tests with coverage report
coverage-generate: deps
	@$(GRADLE) test jacocoTestReport

#coverage-check: @ Verify code coverage meets minimum threshold (> 60%)
coverage-check: coverage-generate
	@$(GRADLE) jacocoTestCoverageVerification

#coverage-open: @ Open code coverage report in browser
coverage-open:
	@$(OPEN_CMD) ./app/build/reports/jacoco/test/html/index.html

#deps-hadolint: @ Ensure hadolint is installed (via mise)
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { \
		command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }; \
		mise install hadolint; \
	}

#deps-docker: @ Ensure Docker is installed
deps-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: Docker required. Install: https://docs.docker.com/get-docker/"; exit 1; }

#image-build: @ Build Docker image
image-build: deps-docker build
	@docker buildx build --load -t $(DOCKER_IMAGE) .
	@docker tag $(DOCKER_IMAGE) $(DOCKER_FULL_IMAGE)

#image-run: @ Run Docker image
image-run: deps-docker
	@docker run --rm --name $(APP_NAME) $(DOCKER_IMAGE)

#image-stop: @ Stop running Docker container
image-stop:
	@docker stop $(APP_NAME) 2>/dev/null || true

#image-build-run: @ Build and run Docker image
image-build-run: image-build image-run

#image-push: @ Push Docker image to registry
image-push: image-build
	@docker push $(DOCKER_FULL_IMAGE)

#gradle-stop: @ Stop all Gradle daemons
gradle-stop:
	@$(GRADLE) --stop

#upgrade: @ Check for dependency updates
upgrade: deps
	@$(GRADLE) :app:dependencyUpdates $(NO_CACHE)

#renovate-bootstrap: @ Ensure Node is installed (via mise)
renovate-bootstrap:
	@command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }
	@mise install node

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }
	@mise exec node -- npx -p renovate -c "renovate-config-validator"

#deps-prune: @ Show dependency tree for manual pruning review
deps-prune: deps
	@echo "=== Dependency Pruning (Gradle) ==="
	@$(GRADLE) :app:dependencies --configuration runtimeClasspath
	@echo "=== Review above for unused or redundant dependencies ==="

#deps-prune-check: @ Verify no prunable dependencies (CI gate)
deps-prune-check: deps
	@echo "=== Dependency Prune Check (Gradle) ==="
	@if $(GRADLE) :app:dependencies --configuration runtimeClasspath 2>&1 | grep -iE '(FAILED|could not resolve)'; then \
		echo "ERROR: Unresolvable dependencies found. Run 'make deps-prune' to review."; exit 1; \
	fi
	@echo "No prunable dependency issues detected."

#deps-act: @ Ensure act is installed (via mise)
deps-act: deps
	@command -v act >/dev/null 2>&1 || { \
		command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Run: make deps-install"; exit 1; }; \
		mise install act; \
	}

#ci: @ Run full CI pipeline locally (mirrors GitHub Actions)
ci: deps static-check test integration-test coverage-check build
	@echo "=== CI Complete ==="

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@docker container prune -f 2>/dev/null || true
	@# Pass secret NAMES only (no =VALUE) so act reads values from env —
	@# avoids leaking credentials in `ps aux` output.
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts \
		--var ACT=true \
		$$([ -n "$${NVD_API_KEY:-}" ] && echo "--secret NVD_API_KEY") \
		$$([ -n "$${OSS_INDEX_USER:-}" ] && echo "--secret OSS_INDEX_USER") \
		$$([ -n "$${OSS_INDEX_TOKEN:-}" ] && echo "--secret OSS_INDEX_TOKEN")

#ci-docker: @ Run full CI pipeline including Docker build
ci-docker: ci image-build
	@echo "=== CI Docker Complete ==="

#release: @ Create and push a new tag
release: deps
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add ./version.txt && \
		git commit -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#tmux-session: @ Launch tmux session with Claude
tmux-session:
	@tmux has-session -t gradle-fips-test 2>/dev/null || tmux new-session -d -s gradle-fips-test
	@tmux send-keys -t gradle-fips-test "claude" C-m
	@if [ -n "$$TMUX" ]; then tmux switch-client -t gradle-fips-test; else tmux attach-session -t gradle-fips-test; fi

.PHONY: help deps deps-install deps-check clean build format format-check lint \
	secrets trivy-fs mermaid-lint static-check test integration-test run \
	cve-check cve-db-update cve-db-purge \
	coverage-generate coverage-check coverage-open \
	deps-hadolint deps-gitleaks deps-trivy deps-docker \
	image-build image-run image-stop image-build-run image-push \
	gradle-stop upgrade renovate-bootstrap renovate-validate \
	deps-prune deps-prune-check deps-act ci ci-run ci-docker release tmux-session
