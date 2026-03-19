[![ci](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/gradle-java-simple)
# Gradle based Java project for general purpose testing

## Pre-requisites

- [`GNU Make`](https://www.gnu.org/software/make/)
- [curl](https://curl.se/) (for automatic sdkman installation)

> **Note:** `make deps` (or `make build`) will automatically install [sdkman](https://sdkman.io/install), IBM Semeru 21, and Gradle if they are not already present.

### Optional

- [Docker](https://docs.docker.com/get-docker/) (for `docker-build`, `docker-run`, `docker-push` targets)
- [nvm](https://github.com/nvm-sh/nvm) (for `validate-renovate` target; install via `make bootstrap-renovate`)

## Usage

Verify and install dependencies:
```bash
make deps
```

Build:
```bash
make build
```

Run tests:
```bash
make test
```

Run:
```bash
make run
```

Run dependencies check for publicly disclosed vulnerabilities in application dependencies:
```bash
make cve-check
```

Run full CI pipeline locally:
```bash
make ci
```

### Help

```bash
make help
```

```text
Usage: make COMMAND

Commands :

help              - List available tasks
deps              - Verify and install required build dependencies
clean             - Clean build artifacts
build             - Build project
lint              - Run Java code style checks (Checkstyle)
test              - Run project tests
run               - Run project
cve-check         - Run OWASP dependency vulnerability scan (needs NVD_API_KEY)
cve-db-update     - Update vulnerability database manually
cve-db-purge      - Purge local database (forces fresh download)
coverage-generate - Run tests with coverage report
coverage-check    - Verify code coverage meets minimum threshold (> 60%)
coverage-open     - Open code coverage report in browser
docker-build      - Build Docker image
docker-run        - Run Docker image
docker-image      - Build and run Docker image
docker-push       - Push Docker image to registry
stop-gradle       - Stop all Gradle daemons
upgrade           - Check for dependency updates
bootstrap-renovate - Install nvm and npm for renovate
validate-renovate - Validate Renovate configuration
ci                - Run full CI pipeline locally (mirrors GitHub Actions)
ci-docker         - Run full CI pipeline including Docker build
tmux-session      - Launch tmux session with Claude
```

## Semeru 21 FIPS

Uses the public IBM Semeru runtime from IBM Container Registry (`icr.io/appcafe`):

```bash
docker pull icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal
docker run --rm -it icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal /bin/bash
```

```bash
java -version
java -XshowSettings:properties -version 2>&1 | grep -i "java.home"
ls -la /opt/java/openjdk/conf/security/
grep -i "OpenJCEPlus" /opt/java/openjdk/conf/security/java.security
grep "^security.provider" /opt/java/openjdk/conf/security/java.security
find / -name "*OpenJCEPlus*" -o -name "*FIPS*" 2>/dev/null
```
