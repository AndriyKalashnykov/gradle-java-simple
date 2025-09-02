.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := ~/.sdkman/bin/sdkman-init.sh
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
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-9s\033[0m - %s\n", $$1, $$2}'

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

#check-env: @ Check environment variables and installed tools
check-env: build-deps-check

	@printf "\xE2\x9C\x94 "
	$(SDKMAN_EXISTS)
	@printf "\n"

#cve-check-dep: @ Dependency Check Analysis and a Custom Security Scan task
cve-check-dep: check-env
	@ ./gradlew clean  :app:dependencyCheckAnalyze :app:securityScan --no-configuration-cache --warning-mode all

#cve-db-update @ Update vulnerability database manually
cve-db-update:
	@ ./gradlew dependencyCheckUpdate

#cve-db-purge: Purge local database (forces fresh download)
cve-db-purge:
	@ ./gradlew dependencyCheckPurge

#test: @ Test project
test: check-env build
	@ ./gradlew clean test

#build: @ Build project
build: check-env
	@ ./gradlew clean build

#run: @ Run project
run: check-env test
	@ ./gradlew clean :app:run --no-configuration-cache --warning-mode all

stop-gradle:
	@ ./gradlew --stop
	@ pkill -f '.*GradleDaemon.*'