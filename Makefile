.DEFAULT_GOAL := help
SHELL := /bin/bash

APP_NAME    := gradle-java-fips-test
GRADLE      := ./gradlew
NO_CACHE    := --no-configuration-cache
JAVA_VER    := 21.0.10.1-sem  # derive: sdk list java | grep sem
GRADLE_VER  := 9.4.1       # derive: sdk list gradle
ACT_VERSION := 0.2.87      # derive: gh api repos/nektos/act/releases/latest --jq '.tag_name'
NVM_VERSION := 0.40.4      # derive: gh api repos/nvm-sh/nvm/releases/latest --jq '.tag_name'
NODE_VERSION := 22          # derive: node --version (major only)
CURRENTTAG  := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

DOCKER_IMAGE      := $(APP_NAME)
DOCKER_REGISTRY   ?= docker.io
DOCKER_REPO       ?= $(shell whoami)/$(DOCKER_IMAGE)
DOCKER_TAG        ?= latest
DOCKER_FULL_IMAGE := $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(DOCKER_TAG)

OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

#help: @ List available tasks
help:
	@echo -e "Usage: make COMMAND\n\nCommands :\n"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST) | tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-18s\033[0m - %s\n", $$1, $$2}'

#deps: @ Verify required build dependencies are available
deps:
	@command -v curl >/dev/null 2>&1 || { echo "Error: curl required."; exit 1; }
	@java -version 2>&1 | grep -q "\"21\." || { echo "Error: Java 21 required. Run: make deps-check"; exit 1; }
	@[ -x "$(GRADLE)" ] || { echo "Error: Gradle wrapper (gradlew) not found. Run: make deps-check"; exit 1; }

#deps-check: @ Install Java and Gradle via SDKMAN
deps-check:
	@bash -c '\
	  set -eo pipefail; \
	  export SDKMAN_DIR="$${SDKMAN_DIR:-$$HOME/.sdkman}"; \
	  if [[ -s "$$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then \
	    source "$$SDKMAN_DIR/bin/sdkman-init.sh"; \
	  else \
	    echo "Installing SDKMAN..."; \
	    curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
	    source "$$SDKMAN_DIR/bin/sdkman-init.sh"; \
	  fi; \
	  export SDKMAN_AUTO_ANSWER=true; \
	  sdk install java "$(JAVA_VER)" 2>/dev/null || true; sdk use java "$(JAVA_VER)"; \
	  sdk install gradle "$(GRADLE_VER)" 2>/dev/null || true; sdk use gradle "$(GRADLE_VER)"; \
	  echo "Done. Open a new terminal or run: source $$SDKMAN_DIR/bin/sdkman-init.sh"; \
	'

#clean: @ Clean build artifacts
clean:
	@$(GRADLE) clean && rm -rf build app/build

#build: @ Build project
build: deps
	@$(GRADLE) build

#lint: @ Run Java code style checks (Checkstyle)
lint: deps
	@$(GRADLE) checkstyleMain checkstyleTest

#test: @ Run project tests
test: deps
	@$(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3

#run: @ Run project
run: deps
	@$(GRADLE) :app:run $(NO_CACHE) --warning-mode all

#cve-check: @ Run OWASP dependency vulnerability scan (needs NVD_API_KEY)
cve-check: deps
	@[ -n "$${NVD_API_KEY:-}" ] || echo "Warning: NVD_API_KEY not set"
	@$(GRADLE) :app:securityScan $(NO_CACHE) --warning-mode all

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

#renovate-bootstrap: @ Install nvm and npm for renovate
renovate-bootstrap:
	@bash -c '\
	  export NVM_DIR="$${NVM_DIR:-$$HOME/.nvm}"; \
	  if [ ! -d "$$NVM_DIR" ]; then \
	    echo "Installing nvm $(NVM_VERSION)..."; \
	    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
	  else echo "nvm already installed"; fi; \
	  [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
	  nvm install $(NODE_VERSION); nvm use $(NODE_VERSION); \
	'

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@bash -c '\
	  export NVM_DIR="$${NVM_DIR:-$$HOME/.nvm}"; \
	  [ -s "$$NVM_DIR/nvm.sh" ] || { echo "Error: nvm not found. Run: make renovate-bootstrap"; exit 1; }; \
	  . "$$NVM_DIR/nvm.sh"; npx -p renovate -c "renovate-config-validator"; \
	'

#deps-act: @ Install act for local GitHub Actions testing
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#ci: @ Run full CI pipeline locally (mirrors GitHub Actions)
ci: deps
	@echo "=== CI Step 1/5: Lint ===" && $(GRADLE) checkstyleMain checkstyleTest
	@echo "=== CI Step 2/5: Test ===" && $(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3
	@echo "=== CI Step 3/5: Coverage ===" && $(GRADLE) jacocoTestReport jacocoTestCoverageVerification
	@echo "=== CI Step 4/5: Build ===" && $(GRADLE) clean build
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

.PHONY: help deps deps-check clean build lint test run \
	cve-check cve-db-update cve-db-purge \
	coverage-generate coverage-check coverage-open \
	deps-docker image-build image-run image-stop image-build-run image-push \
	gradle-stop upgrade renovate-bootstrap renovate-validate \
	deps-act ci ci-run ci-docker release tmux-session
