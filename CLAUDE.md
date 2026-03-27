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
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make ci-docker` | Run full CI pipeline including Docker build |
| `make image-build` | Build Docker image |
| `make image-run` | Run Docker image |
| `make image-build-run` | Build and run Docker image |
| `make image-push` | Push Docker image to registry |
| `make upgrade` | Check for dependency updates |
| `make release` | Create and push a new semver tag |

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
make image-build      # Build image
make image-run        # Run existing image
make image-build-run  # Build and run
make image-push       # Push to registry
```

Configure push target with environment variables:
- `DOCKER_REGISTRY` (default: `docker.io`)
- `DOCKER_REPO` (default: `<username>/gradle-java-fips-test`)
- `DOCKER_TAG` (default: `latest`)

## CI

GitHub Actions (`.github/workflows/ci.yml`):
- **build-and-test** job: sequential `make build`, `make lint`, `make test`, `make coverage-check`, `make run` steps
- **docker** job: tag-gated (`if: startsWith(github.ref, 'refs/tags/')`), builds and pushes Docker image **after** build-and-test passes (`needs: build-and-test`)
- **concurrency**: superseded runs on the same branch are automatically cancelled
- No sdkman in CI — `deps` detects system Java 21 and skips sdkman installation. JDK via `actions/setup-java`, Gradle via `gradle/actions/setup-gradle` (includes caching)

**Note:** `actions/upload-artifact` is pinned to v4 (v4.6.2, hash `ea165f8d`). v7's ESM migration breaks `act` local CI. A Renovate package rule prevents auto-upgrading past v4. To upgrade, test incrementally (v5→v6→v7) with `make ci-run` and update the constraint when verified.

Run CI locally before pushing: `make ci` (mirrors the build-and-test job)
Run CI with Docker: `make ci-docker`
Run GitHub Actions locally: `make ci-run` (uses [act](https://github.com/nektos/act))

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
