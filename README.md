[![CI](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/gradle-java-simple/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/gradle-java-simple)

# Gradle Java FIPS Validation Project

A Gradle-based Java 21 project that validates [FIPS 140-3](https://csrc.nist.gov/projects/cryptographic-module-validation-program) compliance using IBM Semeru JDK. It detects FIPS mode by inspecting JDK system properties, JCE crypto policy, and registered security providers.

## Quick Start

```bash
make deps-check  # install Java 21 and Gradle via SDKMAN (first time only)
make build       # build the project
make test        # run tests
make run         # run the application
```

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [curl](https://curl.se/) | any | SDKMAN auto-installation |
| [SDKMAN](https://sdkman.io/) | latest | Java/Gradle version management |
| [Docker](https://docs.docker.com/get-docker/) | latest | Only for `image-*` targets (optional) |

Install all required dependencies:

```bash
make deps-check
```

## Make Targets

### Build & Run

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make deps` | Verify required build dependencies are available |
| `make deps-check` | Install Java and Gradle via SDKMAN |
| `make build` | Build project |
| `make test` | Run project tests |
| `make run` | Run project |
| `make clean` | Clean build artifacts |

### Code Quality

| Target | Description |
|--------|-------------|
| `make lint` | Run Java code style checks (Checkstyle) |
| `make coverage-generate` | Run tests with coverage report |
| `make coverage-check` | Verify code coverage meets minimum threshold (> 60%) |
| `make coverage-open` | Open code coverage report in browser |
| `make cve-check` | Run OWASP dependency vulnerability scan (needs `NVD_API_KEY`) |
| `make cve-db-update` | Update vulnerability database manually |
| `make cve-db-purge` | Purge local database (forces fresh download) |

### Docker

Builds a multi-stage image: Gradle builder + IBM Semeru 21 FIPS runtime (UBI9).

| Target | Description |
|--------|-------------|
| `make image-build` | Build Docker image |
| `make image-run` | Run Docker image |
| `make image-stop` | Stop running Docker container |
| `make image-build-run` | Build and run Docker image |
| `make image-push` | Push Docker image to registry |

Configure the push target with environment variables:

```bash
DOCKER_REGISTRY=docker.io DOCKER_REPO=myuser/myimage DOCKER_TAG=v1 make image-push
```

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full CI pipeline locally (mirrors GitHub Actions) |
| `make ci-run` | Run GitHub Actions workflow locally using [act](https://github.com/nektos/act) |
| `make ci-docker` | Run full CI pipeline including Docker build |
| `make deps-act` | Install act for local GitHub Actions testing |
| `make release` | Create and push a new tag |

### Utilities

| Target | Description |
|--------|-------------|
| `make upgrade` | Check for dependency updates |
| `make gradle-stop` | Stop all Gradle daemons |
| `make renovate-bootstrap` | Install nvm and npm for renovate |
| `make renovate-validate` | Validate Renovate configuration |
| `make tmux-session` | Launch tmux session with Claude |

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

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main`, tags `v*`, and pull requests:

1. **build-and-test** — `make build`, `make lint`, `make test`, `make coverage-check`, `make run`
2. **docker** — tag-gated (`if: startsWith(github.ref, 'refs/tags/')`) — builds and pushes Docker image after build-and-test passes (requires registry variables/secrets)

A weekly [cleanup workflow](.github/workflows/cleanup-runs.yml) deletes old workflow runs (retains 7 days, minimum 5 runs).

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
