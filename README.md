[![ci](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/gradle-java-simple)

# Gradle Java FIPS Validation Project

A Gradle-based Java 21 project that validates [FIPS 140-3](https://csrc.nist.gov/projects/cryptographic-module-validation-program) compliance using IBM Semeru JDK. It detects FIPS mode by inspecting JDK system properties, JCE crypto policy, and registered security providers.

## Quick Start

```bash
make build   # installs dependencies (sdkman, IBM Semeru 21, Gradle) then builds
make test    # runs FIPS validation tests
make run     # runs the app
```

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| [GNU Make](https://www.gnu.org/software/make/) | Yes | Build orchestration |
| [curl](https://curl.se/) | Yes | sdkman auto-installation |
| [Docker](https://docs.docker.com/get-docker/) | No | Only for `docker-*` targets |

`make deps` (or `make build`) automatically installs [sdkman](https://sdkman.io/install), IBM Semeru 21, and Gradle if missing.

## Make Targets

### Build & Run

| Target | Description |
|--------|-------------|
| `make deps` | Install/verify dependencies (sdkman, Java 21, Gradle) |
| `make build` | Build project (runs `deps` first) |
| `make test` | Run FIPS validation tests |
| `make run` | Run the application |
| `make clean` | Remove build artifacts |

### Code Quality

| Target | Description |
|--------|-------------|
| `make lint` | Run Checkstyle (120 char lines, 50 line methods) |
| `make coverage-generate` | Run tests with JaCoCo coverage report |
| `make coverage-check` | Verify coverage meets 60% minimum |
| `make coverage-open` | Open coverage report in browser |
| `make cve-check` | OWASP dependency vulnerability scan (needs `NVD_API_KEY`) |

### Docker

Builds a multi-stage image: Gradle builder + IBM Semeru 21 FIPS runtime (UBI9).

| Target | Description |
|--------|-------------|
| `make docker-build` | Build Docker image |
| `make docker-run` | Run Docker image |
| `make docker-image` | Build and run |
| `make docker-push` | Push to registry |

Configure the push target with environment variables:

```bash
DOCKER_REGISTRY=docker.io DOCKER_REPO=myuser/myimage DOCKER_TAG=v1 make docker-push
```

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full pipeline locally: build, lint, test, coverage, run |
| `make ci-docker` | Full pipeline + Docker build |

### Utilities

| Target | Description |
|--------|-------------|
| `make upgrade` | Check for dependency updates |
| `make stop-gradle` | Stop all Gradle daemons |
| `make validate-renovate` | Validate Renovate config (needs nvm; `make bootstrap-renovate` to install) |

## Project Structure

```
app/src/main/java/org/example/
├── App.java                  # Main application (greeting/message)
├── FIPSValidator.java        # FIPS mode detection logic
└── FIPSValidatorRunner.java  # Standalone runner (Docker entry point)
```

`FIPSValidator` checks for FIPS mode via:
1. `semeru.fips` and `semeru.customprofile` system properties
2. JCE unlimited crypto policy
3. Red Hat FIPS property (`com.redhat.fips`)
4. Registered security providers (OpenJCEPlusFIPS)

## CI/CD

GitHub Actions runs two parallel jobs on every push/PR to `main`:

1. **build-and-test** — build, lint, test, coverage verification, app run
2. **docker** — build Docker image (push only on main merge with registry secrets configured)

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## FIPS Runtime Details

The Docker image uses the public IBM Semeru runtime from [IBM Container Registry](https://icr.io/appcafe):

```bash
docker pull icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal
```

FIPS mode is activated by JVM flags:

```
-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3
```

To inspect FIPS providers interactively:

```bash
docker run --rm -it icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal /bin/bash
java -version
grep "^security.provider" /opt/java/openjdk/conf/security/java.security
```
