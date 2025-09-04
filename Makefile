.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := $(HOME)/.sdkman/bin/sdkman-init.sh
CURRENT_USER_NAME := $(shell whoami)

JAVA_VER  := 21-tem
GRADLE_VER := 9.0.0

SDKMAN_EXISTS := @printf "sdkman"
NODE_EXISTS := @printf "npm"


#help: @ List available tasks
help:
	@clear
	@echo "Usage: make COMMAND"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-13s\033[0m - %s\n", $$1, $$2}'

build-deps-check:
	@. $(SDKMAN)
ifndef SDKMAN_DIR
	@curl -s "https://get.sdkman.io?rcupdate=false" | bash
	@source $(SDKMAN)
	ifndef SDKMAN_DIR
		SDKMAN_EXISTS := @echo "SDKMAN_VERSION is undefined" && exit 1
	endif
endif

	@. $(SDKMAN) && echo N | sdk install java $(JAVA_VER) && sdk use java $(JAVA_VER)
	@. $(SDKMAN) && echo N | sdk install gradle $(GRADLE_VER) && sdk use gradle $(GRADLE_VER)

#clean: @ Cleanup
clean:
	@ ./gradlew clean && rm -rf .gradle build app/build

#check-env: @ Check installed tools
check-env: build-deps-check

	@printf "\xE2\x9C\x94 "
	$(SDKMAN_EXISTS)
	@printf "\n"

#cve-dep-check: @ Dependency Check Analysis and a Custom Security Scan task
cve-dep-check:
	@ ./gradlew clean  :app:dependencyCheckAnalyze :app:securityScan --no-configuration-cache --warning-mode all

#cve-db-update @ Update vulnerability database manually
cve-db-update:
	@ ./gradlew dependencyCheckUpdate

#cve-db-purge: Purge local database (forces fresh download)
cve-db-purge:
	@ ./gradlew dependencyCheckPurge

#test: @ Test project
test: build
	@ ./gradlew clean test

#j-generate: @ Run tests with coverage report
j-generate: build
	@ ./gradlew clean test jacocoTestReport
	@echo "Coverage report available at: ./app/build/reports/jacoco/test/html/index.html"

#j-check: @ Verify code coverage meets minimum threshold ( > 60%)
j-check: j-generate
	@ ./gradlew jacocoTestCoverageVerification

#j-open: @ Open code coverage report
j-open:
	@ xdg-open ./app/build/reports/jacoco/test/html/index.html

#build: @ Build project
build:
	@ ./gradlew clean build

#run: @ Run project
run: test
	@ ./gradlew clean :app:run --no-configuration-cache --warning-mode all

stop-gradle:
	@ ./gradlew --stop
	@ pkill -f '.*GradleDaemon.*'

