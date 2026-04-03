# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Gradle-based Java 21 project used for general-purpose testing, with a focus on FIPS (Federal Information Processing Standards) validation for IBM Semeru JDK environments.

## Build Commands

All commands use `make` as the primary interface (wraps `./gradlew`):

| Command | Description |
|---------|-------------|
| `make help` | List available tasks |
| `make deps` | Verify required build dependencies are available |
| `make deps-check` | Install Java and Gradle via SDKMAN |
| `make build` | Build project (runs `deps` first) |
| `make test` | Run project tests |
| `make run` | Run the app |
| `make clean` | Clean build artifacts |
| `make lint` | Run Java code style checks (Checkstyle) |
| `make coverage-generate` | Run tests with coverage report |
| `make coverage-check` | Verify code coverage meets minimum threshold (> 60%) |
| `make coverage-open` | Open code coverage report in browser |
| `make cve-check` | OWASP dependency vulnerability scan (needs `NVD_API_KEY` env var) |
| `make cve-db-update` | Update vulnerability database manually |
| `make cve-db-purge` | Purge local database (forces fresh download) |
| `make image-build` | Build Docker image |
| `make image-run` | Run Docker image |
| `make image-stop` | Stop running Docker container |
| `make image-build-run` | Build and run Docker image |
| `make image-push` | Push Docker image to registry |
| `make gradle-stop` | Stop all Gradle daemons |
| `make upgrade` | Check for dependency updates |
| `make renovate-bootstrap` | Install nvm and npm for renovate |
| `make renovate-validate` | Validate Renovate configuration |
| `make deps-act` | Install act for local GitHub Actions testing |
| `make ci` | Run full CI pipeline locally (mirrors GitHub Actions) |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make ci-docker` | Run full CI pipeline including Docker build |
| `make release` | Create and push a new tag |
| `make tmux-session` | Launch tmux session with Claude |

**Target design:** `deps` checks that tools are available (fails fast with instructions to run `deps-check` if missing). All targets that invoke Gradle depend on `deps` for reliable error messages on a fresh checkout. The `ci` target orchestrates the full pipeline as a linear sequence. `image-build` depends on both `deps-docker` and `build`. `renovate-validate` depends on `renovate-bootstrap`.

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

Multi-stage build: Gradle builder stage (uses `installDist` to produce only the app JAR + dependency JARs) + IBM Semeru 21 FIPS-enabled runtime (`ubi9`). Runs `FIPSValidatorRunner` as entry point. Only `/app/lib/*.jar` is copied to the runtime image — no Gradle cache bloat.

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
- **static-check** job: `make lint` — runs first (cheapest, fail-fast)
- **build** job: `make build`, `make run` — runs after static-check passes (`needs: [static-check]`)
- **test** job: `make test`, `make coverage-check` — runs in parallel with build after static-check (`needs: [static-check]`)
- **docker** job: tag-gated (`if: startsWith(github.ref, 'refs/tags/')`), builds and pushes Docker image after build and test pass (`needs: [build, test]`)
- **concurrency**: superseded runs on the same branch are automatically cancelled
- No sdkman in CI — `deps` checks for system Java 21 and `gradle` (both provided by actions). JDK via `actions/setup-java`, Gradle via `gradle/actions/setup-gradle` (includes caching)

Cleanup workflow (`.github/workflows/cleanup-runs.yml`): weekly cron that deletes old workflow runs (retains 7 days, minimum 5 runs).

**Note:** `actions/upload-artifact` is at v7 (hash `bbbca2dd`). Artifact uploads fail locally in act (protocol mismatch with act's artifact server), but `continue-on-error: true` ensures jobs still pass. Artifacts upload correctly on real GitHub Actions.

Run CI locally before pushing: `make ci` (mirrors the static-check → build → test pipeline)
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

## Upgrade Backlog

Deferred upgrade items from analysis on 2026-04-03. Review periodically — resolve actionable items, remove stale ones.

- [ ] **FIPS profile hard expiry 2026-09-21** — Semeru JDK FIPS profile `OpenJCEPlusFIPS.FIPS140-3` expires on this date. App will refuse to start after. Updated to 21.0.10.1-sem but expiry unchanged — need a future Semeru release from IBM. Check: `make run` output for expiry warning.
- [x] ~~**upload-artifact v4 → v7 migration**~~ — Completed 2026-04-03. Tested v5 (full act support), v6 (auth error in act), v7 (protocol mismatch in act). All pass with `continue-on-error: true`. Removed Renovate pin constraint.
- [ ] **`JAVA_VER` not tracked by Renovate** — SDKMAN version format (`21.0.10.1-sem`) has no Renovate datasource. Must manually check for Semeru JDK updates via `sdk list java | grep sem`.
- [x] ~~**commons-math3 stale since 2016**~~ — Resolved 2026-04-03. Removed entirely — was a dead entry in `libs.versions.toml` with no imports in source code.
- [ ] **Gradle 10 compatibility** — ben-manes versions plugin triggers deprecation warning. Watch for plugin update. Check: `./gradlew dependencyUpdates --warning-mode all`.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
