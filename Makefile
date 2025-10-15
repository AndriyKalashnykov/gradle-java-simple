.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := $(HOME)/.sdkman/bin/sdkman-init.sh
CURRENT_USER_NAME := $(shell whoami)

JAVA_VER  := 21-tem
GRADLE_VER := 9.0.0

SDKMAN_EXISTS := @printf "sdkman"
NODE_EXISTS := @printf "npm"

IS_DARWIN := 0
IS_LINUX := 0
IS_FREEBSD := 0
IS_WINDOWS := 0
IS_AMD64 := 0
IS_AARCH64 := 0
IS_RISCV64 := 0

# Platform and architecture detection
ifeq ($(OS), Windows_NT)
	IS_WINDOWS := 1
	# Windows architecture detection using PROCESSOR_ARCHITECTURE
	ifeq ($(PROCESSOR_ARCHITECTURE), AMD64)
		IS_AMD64 := 1
	else ifeq ($(PROCESSOR_ARCHITECTURE), x86)
		# 32-bit x86 - you might want to add IS_X86 := 1 if needed
		IS_AMD64 := 0
	else ifeq ($(PROCESSOR_ARCHITECTURE), ARM64)
		IS_AARCH64 := 1
	else
		# Fallback: check PROCESSOR_ARCHITEW6432 for 32-bit processes on 64-bit systems
		ifeq ($(PROCESSOR_ARCHITEW6432), AMD64)
			IS_AMD64 := 1
		else ifeq ($(PROCESSOR_ARCHITEW6432), ARM64)
			IS_AARCH64 := 1
		else
			# Default to AMD64 if unable to determine
			IS_AMD64 := 1
		endif
	endif
else
	# Unix-like systems - detect platform and architecture
	UNAME_S := $(shell uname -s)
	UNAME_M := $(shell uname -m)

	# Platform detection
	ifeq ($(UNAME_S), Darwin)
		IS_DARWIN := 1
	else ifeq ($(UNAME_S), Linux)
		IS_LINUX := 1
	else ifeq ($(UNAME_S), FreeBSD)
		IS_FREEBSD := 1
	else
		$(error Unsupported platform: $(UNAME_S). Supported platforms: Darwin, Linux, FreeBSD, Windows_NT)
	endif

	# Architecture detection
	ifneq (, $(filter $(UNAME_M), x86_64 amd64))
		IS_AMD64 := 1
	else ifneq (, $(filter $(UNAME_M), aarch64 arm64))
		IS_AARCH64 := 1
	else ifneq (, $(filter $(UNAME_M), riscv64))
		IS_RISCV64 := 1
	else
		$(error Unsupported architecture: $(UNAME_M). Supported architectures: x86_64/amd64, aarch64/arm64, riscv64)
	endif
endif

#help: @ List available tasks
help:
	@clear
	@echo "Usage: make COMMAND"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-17s\033[0m - %s\n", $$1, $$2}'

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

#check-env: @ Check installed tools
check-env: build-deps-check

	@printf "\xE2\x9C\x94 "
	$(SDKMAN_EXISTS)
	@printf "\n"

#clean: @ Cleanup
clean:
	@ ./gradlew clean && rm -rf .gradle build app/build

#test: @ Run project tests
test: build
	@ ./gradlew clean :app:test --tests "org.example.FIPSValidatorTest" --info -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3

#build: @ Build project
build:
	@ ./gradlew clean build

#run: @ Run project
run: test
	@ ./gradlew clean :app:run --no-configuration-cache --warning-mode all

#cve-check: @ Run dependencies check for publicly disclosed vulnerabilities in application dependencies
cve-check:
	@ ./gradlew clean  :app:dependencyCheckAnalyze :app:securityScan --no-configuration-cache --warning-mode all

#cve-db-update @ Update vulnerability database manually
cve-db-update:
	@ ./gradlew dependencyCheckUpdate

#cve-db-purge: Purge local database (forces fresh download)
cve-db-purge:
	@ ./gradlew dependencyCheckPurge

#coverage-generate: @ Run tests with coverage report
coverage-generate: build
	@ ./gradlew clean test jacocoTestReport
	@echo "Coverage report available at: ./app/build/reports/jacoco/test/html/index.html"

#coverage-check: @ Verify code coverage meets minimum threshold ( > 60%)
coverage-check: coverage-generate
	@ ./gradlew jacocoTestCoverageVerification

#coverage-open: @ Open code coverage report
coverage-open:
	@ $(if $(filter 1,$(IS_DARWIN)),open,xdg-open) ./app/build/reports/jacoco/test/html/index.html

stop-gradle:
	@ ./gradlew --stop
	@ pkill -f '.*GradleDaemon.*'

docker-image:
	docker build --load -t gradle-java-fips-test .
	docker run --rm gradle-java-fips-test