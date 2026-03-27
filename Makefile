.DEFAULT_GOAL := help
SHELL := /bin/bash

GRADLE      := ./gradlew
NO_CACHE    := --no-configuration-cache
JAVA_VER    := 21.0.10-sem
GRADLE_VER  := 9.4.1
ACT_VERSION := 0.2.86
NVM_VERSION := 0.40.4
CURRENTTAG  := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

DOCKER_IMAGE      := gradle-java-fips-test
DOCKER_REGISTRY   ?= docker.io
DOCKER_REPO       ?= $(shell whoami)/$(DOCKER_IMAGE)
DOCKER_TAG        ?= latest
DOCKER_FULL_IMAGE := $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(DOCKER_TAG)

OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

#help: @ List available tasks
help:
	@echo -e "Usage: make COMMAND\n\nCommands :\n"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-18s\033[0m - %s\n", $$1, $$2}'

#deps: @ Verify and install required build dependencies
deps:
	@bash -c '\
	  set -eo pipefail; \
	  ok()   { printf "\033[32m[OK]\033[0m    %s\n" "$$1"; }; \
	  warn() { printf "\033[33m[WARN]\033[0m  %s\n" "$$1"; }; \
	  fail() { printf "\033[31m[FAIL]\033[0m  %s\n" "$$1"; exit 1; }; \
	  command -v curl >/dev/null 2>&1 && ok "curl" || fail "curl not found"; \
	  if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -q "\"21\."; then \
	    ok "Java 21 (system)"; \
	  else \
	    export SDKMAN_DIR="$${SDKMAN_DIR:-$$HOME/.sdkman}"; \
	    if [[ -s "$$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then \
	      source "$$SDKMAN_DIR/bin/sdkman-init.sh"; ok "SDKMAN"; \
	    else \
	      warn "SDKMAN not found -- installing..."; \
	      curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
	      source "$$SDKMAN_DIR/bin/sdkman-init.sh"; ok "SDKMAN installed"; \
	    fi; \
	    export SDKMAN_AUTO_ANSWER=true; \
	    sdk install java "$(JAVA_VER)" 2>/dev/null || true; sdk use java "$(JAVA_VER)"; ok "Java $(JAVA_VER)"; \
	    sdk install gradle "$(GRADLE_VER)" 2>/dev/null || true; sdk use gradle "$(GRADLE_VER)"; ok "Gradle $(GRADLE_VER)"; \
	  fi; \
	  [[ -x "./gradlew" ]] && ok "Gradle wrapper" || fail "Gradle wrapper (gradlew) not found"; \
	  command -v docker >/dev/null 2>&1 && ok "Docker (optional)" || warn "Docker not found (needed for image-* targets)"; \
	'

#clean: @ Clean build artifacts
clean:
	@$(GRADLE) clean && rm -rf build app/build

#build: @ Build project
build: deps
	@$(GRADLE) build

#lint: @ Run Java code style checks (Checkstyle)
lint:
	@$(GRADLE) checkstyleMain checkstyleTest

#test: @ Run project tests
test:
	@$(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3

#run: @ Run project
run:
	@$(GRADLE) :app:run $(NO_CACHE) --warning-mode all

#cve-check: @ Run OWASP dependency vulnerability scan (needs NVD_API_KEY)
cve-check:
	@[ -n "$${NVD_API_KEY:-}" ] || echo "Warning: NVD_API_KEY not set"
	@$(GRADLE) :app:securityScan $(NO_CACHE) --warning-mode all

#cve-db-update: @ Update vulnerability database manually
cve-db-update:
	@$(GRADLE) dependencyCheckUpdate $(NO_CACHE)

#cve-db-purge: @ Purge local database (forces fresh download)
cve-db-purge:
	@$(GRADLE) dependencyCheckPurge $(NO_CACHE)

#coverage-generate: @ Run tests with coverage report
coverage-generate:
	@$(GRADLE) test jacocoTestReport

#coverage-check: @ Verify code coverage meets minimum threshold (> 60%)
coverage-check: coverage-generate
	@$(GRADLE) jacocoTestCoverageVerification

#coverage-open: @ Open code coverage report in browser
coverage-open:
	@$(OPEN_CMD) ./app/build/reports/jacoco/test/html/index.html

require-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: Docker required. Install: https://docs.docker.com/get-docker/"; exit 1; }

#image-build: @ Build Docker image
image-build: require-docker
	@docker buildx build --load -t $(DOCKER_IMAGE) .
	@docker tag $(DOCKER_IMAGE) $(DOCKER_FULL_IMAGE)

#image-run: @ Run Docker image
image-run: require-docker
	@docker run --rm $(DOCKER_IMAGE)

#image-build-run: @ Build and run Docker image
image-build-run: image-build image-run

#image-push: @ Push Docker image to registry
image-push: image-build
	@docker push $(DOCKER_FULL_IMAGE)

#stop-gradle: @ Stop all Gradle daemons
stop-gradle:
	@$(GRADLE) --stop

#upgrade: @ Check for dependency updates
upgrade:
	@$(GRADLE) :app:dependencyUpdates $(NO_CACHE)

#bootstrap-renovate: @ Install nvm and npm for renovate
bootstrap-renovate:
	@bash -c '\
	  export NVM_DIR="$${NVM_DIR:-$$HOME/.nvm}"; \
	  if [ ! -d "$$NVM_DIR" ]; then \
	    echo "Installing nvm $(NVM_VERSION)..."; \
	    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
	  else echo "nvm already installed"; fi; \
	  [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
	  nvm install --lts; nvm use --lts; \
	'

#validate-renovate: @ Validate Renovate configuration
validate-renovate:
	@bash -c '\
	  export NVM_DIR="$${NVM_DIR:-$$HOME/.nvm}"; \
	  [ -s "$$NVM_DIR/nvm.sh" ] || { echo "Error: nvm not found. Run: make bootstrap-renovate"; exit 1; }; \
	  . "$$NVM_DIR/nvm.sh"; npx -p renovate -c "renovate-config-validator"; \
	'

#deps-act: @ Install act for local GitHub Actions testing
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#ci: @ Run full CI pipeline locally (mirrors GitHub Actions)
ci: deps
	@echo "=== CI Step 1/5: Build ===" && $(GRADLE) clean build
	@echo "=== CI Step 2/5: Lint ===" && $(GRADLE) checkstyleMain checkstyleTest
	@echo "=== CI Step 3/5: Test ===" && $(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3
	@echo "=== CI Step 4/5: Coverage ===" && $(GRADLE) jacocoTestReport jacocoTestCoverageVerification
	@echo "=== CI Step 5/5: Run ===" && $(GRADLE) :app:run $(NO_CACHE) --warning-mode all
	@echo "=== CI Complete ==="

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#ci-docker: @ Run full CI pipeline including Docker build
ci-docker: ci image-build
	@echo "=== CI Docker Complete ==="

#release: @ Create and push a new tag
release:
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add -A && \
		git commit -a -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#tmux-session: @ Launch tmux session with Claude
tmux-session:
	@tmux has-session -t gradle-fips-test 2>/dev/null || tmux new-session -d -s gradle-fips-test
	@tmux send-keys -t gradle-fips-test "claude" C-m
	@if [ -n "$$TMUX" ]; then tmux switch-client -t gradle-fips-test; else tmux attach-session -t gradle-fips-test; fi

.PHONY: help deps clean build lint test run \
	cve-check cve-db-update cve-db-purge \
	coverage-generate coverage-check coverage-open \
	require-docker image-build image-run image-build-run image-push \
	stop-gradle upgrade bootstrap-renovate validate-renovate \
	deps-act ci ci-run ci-docker release tmux-session
