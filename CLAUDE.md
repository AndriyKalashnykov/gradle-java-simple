# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Gradle-based Java 21 project used for general-purpose testing, with a focus on FIPS (Federal Information Processing Standards) validation for IBM Semeru JDK environments.

## Build Commands

All commands use `make` as the primary interface (wraps `./gradlew`):

| Command | Description |
|---------|-------------|
| `make build` | Build project (runs `deps` first) |
| `make test` | Run FIPSValidatorTest specifically |
| `make run` | Run the app |
| `make clean` | Clean build artifacts |
| `make lint` | Run Java code style checks (Checkstyle) |
| `make deps` | Verify and install build dependencies (sdkman, IBM Semeru 21, Gradle) |
| `make coverage-generate` | Run tests with JaCoCo coverage report |
| `make coverage-check` | Verify coverage meets 60% minimum threshold |
| `make coverage-open` | Open coverage report in browser |
| `make cve-check` | OWASP dependency vulnerability scan (needs `NVD_API_KEY` env var) |
| `make ci` | Run full CI pipeline locally (mirrors GitHub Actions) |
| `make ci-docker` | Run full CI pipeline including Docker build |
| `make docker-build` | Build Docker image only |
| `make docker-run` | Run Docker image |
| `make docker-image` | Build and run Docker image |
| `make docker-push` | Push Docker image to registry |
| `make upgrade` | Check for dependency updates |

**Target design:** Individual targets (`test`, `run`, `lint`, etc.) are self-contained and do not cascade through deep dependency chains. The `ci` target orchestrates the full pipeline as a linear sequence. Only `build` depends on `deps`; other targets assume the environment is already set up (or Gradle handles compilation internally).

### Direct Gradle Commands

```bash
./gradlew clean build                    # Build
./gradlew :app:test                      # Run all tests
./gradlew :app:test --tests "org.example.AppTest"           # Run single test class
./gradlew :app:test --tests "org.example.AppTest.appHasAGreeting"  # Run single test method
./gradlew :app:run                       # Run main app (org.example.App)
./gradlew jacocoTestReport               # Generate coverage report
./gradlew jacocoTestCoverageVerification # Check coverage threshold
./gradlew checkstyleMain checkstyleTest  # Run Checkstyle linting
```

Note: Gradle configuration cache is enabled by default (`gradle.properties`). Some tasks require `--no-configuration-cache` (e.g., `run`, `dependencyCheckAnalyze`).

## Architecture

Single-module Gradle project (`app/`) with standard Java layout:

- **`App`** (`org.example.App`) - Main application class with greeting/message functionality. Entry point.
- **`FIPSValidator`** (`org.example.FIPSValidator`) - Detects FIPS mode by checking Semeru JDK system properties (`semeru.fips`, `semeru.customprofile`), JCE crypto policy, Red Hat FIPS property, and registered security providers.
- **`FIPSValidatorRunner`** (`org.example.FIPSValidatorRunner`) - Standalone runner for FIPS validation, used as Docker container entry point.

## Key Configuration

- **Java 21** (IBM Semeru via sdkman, with toolchain auto-download via foojay-resolver)
- **JVM args for FIPS**: `-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3` (configured in `application` block; tests run with `-Dsemeru.fips=false`)
- **Dependencies** managed via `gradle/libs.versions.toml` (Guava, JUnit Jupiter) and `gradle.properties` (Commons Lang, plugin versions)
- **JaCoCo** minimum coverage: 60%
- **Checkstyle** with custom rules at `config/checkstyle/checkstyle.xml` (120 char line limit, 50 line method limit, 800 line file limit)
- **OWASP Dependency-Check** fails build on CVSS >= 7.0; suppressions in `dependency-check-suppressions.xml`

## Docker

Multi-stage build: Gradle builder stage + IBM Semeru 21 FIPS-enabled runtime (`ubi9`). Runs `FIPSValidatorRunner` as entry point.

```bash
make docker-build   # Build image only
make docker-run     # Run existing image
make docker-image   # Build and run
make docker-push    # Push to registry
```

Configure push target with environment variables:
- `DOCKER_REGISTRY` (default: `docker.io`)
- `DOCKER_REPO` (default: `<username>/gradle-java-fips-test`)
- `DOCKER_TAG` (default: `latest`)

## CI

GitHub Actions (`.github/workflows/ci.yml`):
- **build-and-test** job: single `./gradlew clean build jacocoTestCoverageVerification` invocation (build + lint + test + coverage), then runs the app
- **docker** job: builds Docker image **in parallel** with build-and-test, conditionally pushes on main branch merge
- **concurrency**: superseded runs on the same branch are automatically cancelled
- No sdkman in CI — JDK via `actions/setup-java`, Gradle via `gradle/actions/setup-gradle` (includes caching)

Run CI locally before pushing: `make ci` (mirrors the build-and-test job)
Run CI with Docker: `make ci-docker`

## Claude Code Agent Team

Specialized agents in `.claude/agents/` for development tasks:

| Agent | File | Purpose |
|-------|------|---------|
| Builder | `builder.md` | Build the project, diagnose build failures |
| Test Runner | `test-runner.md` | Run tests, interpret results, FIPS-specific config |
| Code Reviewer | `code-reviewer.md` | Java 21 code review, style, patterns |
| Security Scanner | `security-scanner.md` | OWASP CVE scanning, source code security |
| Coverage Checker | `coverage-checker.md` | JaCoCo coverage verification (60% min) |
| Docker Ops | `docker-ops.md` | Docker build/run/push, FIPS runtime |
| CI Validator | `ci-validator.md` | Run CI pipeline locally before pushing |
| Dependency Manager | `dependency-manager.md` | Upgrade dependencies, manage versions |
| Tech Architect | `tech-architect.md` | System design, abstraction layers, schemas, diagrams, security/compliance |
| Devil's Advocate | `devils-advocate.md` | Challenge decisions, probe conclusions, research alternatives, compile risks |

Teams mode enabled in `.claude/settings.json`. Agents can run in parallel for independent tasks.
