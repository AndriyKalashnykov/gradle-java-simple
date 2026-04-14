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
| `make deps-install` | Install Java via mise (Gradle comes from the wrapper) |
| `make deps-check` | Show required tools and installation status |
| `make build` | Build project (compile only, no tests; depends on `deps`) |
| `make test` | Run FIPS validator tests (`FIPSValidatorTest` only) |
| `make integration-test` | Run integration tests (spawn-JVM subprocess IT suite) |
| `make run` | Run project |
| `make clean` | Clean build artifacts |
| `make format` | Auto-format Java source code (google-java-format) |
| `make format-check` | Verify code formatting (CI gate) |
| `make lint` | Run Checkstyle and Dockerfile lint |
| `make secrets` | Scan for hardcoded secrets with gitleaks |
| `make trivy-fs` | Scan filesystem for vulnerabilities, secrets, misconfigurations |
| `make mermaid-lint` | Validate Mermaid diagrams in markdown files |
| `make static-check` | Composite quality gate (format-check + lint + secrets + trivy-fs + mermaid-lint) |
| `make coverage-generate` | Run tests with coverage report |
| `make coverage-check` | Verify code coverage meets minimum threshold (> 60%) |
| `make coverage-open` | Open code coverage report in browser |
| `make cve-check` | Run OWASP dependency vulnerability scan (needs `NVD_API_KEY`) |
| `make cve-db-update` | Update vulnerability database manually |
| `make cve-db-purge` | Purge local database (forces fresh download) |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-gitleaks` | Install gitleaks for secret scanning |
| `make deps-trivy` | Install Trivy for security scanning |
| `make deps-docker` | Ensure Docker is installed |
| `make image-build` | Build Docker image |
| `make image-run` | Run Docker image |
| `make image-stop` | Stop running Docker container |
| `make image-build-run` | Build and run Docker image |
| `make image-push` | Push Docker image to registry |
| `make gradle-stop` | Stop all Gradle daemons |
| `make upgrade` | Check for dependency updates |
| `make renovate-bootstrap` | Ensure Node is installed (via mise) |
| `make renovate-validate` | Validate Renovate configuration |
| `make deps-prune` | Show dependency tree for manual pruning review |
| `make deps-prune-check` | Verify no prunable dependencies (CI gate) |
| `make deps-act` | Install act for local GitHub Actions testing |
| `make ci` | Run full CI pipeline locally (mirrors GitHub Actions) |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make ci-docker` | Run full CI pipeline including Docker build |
| `make release` | Create and push a new tag |
| `make tmux-session` | Launch tmux session with Claude |

**Target design:** `deps` checks that tools are available (fails fast with instructions to run `deps-install` if missing). Java is pinned in `.mise.toml`; Gradle comes from `./gradlew`. The `static-check` composite target is the single source of truth for quality gates — CI calls it, `make ci` calls it. All targets that invoke Gradle depend on `deps` for reliable error messages on a fresh checkout. Binary tools (hadolint, gitleaks, trivy, act) install to `$HOME/.local/bin` (no sudo). `image-build` depends on `deps-docker` and `build`. `renovate-validate` depends on `renovate-bootstrap`.

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

- **`App`** (`org.example.App`) - Main application class with greeting/message functionality. `make run` entry point (`application { mainClass }`).
- **`FIPSValidator`** (`org.example.FIPSValidator`) - Detects FIPS mode by checking Semeru JDK system properties (`semeru.fips`, `semeru.customprofile`), JCE crypto policy, Red Hat FIPS property, and registered security providers.
- **`FIPSValidatorRunner`** (`org.example.FIPSValidatorRunner`) - Standalone runner for FIPS validation; Docker image `ENTRYPOINT`.

## Key Configuration

- **Java 21** (IBM Semeru OpenJ9 `semeru-openj9-21.0.10+7` via mise / `.mise.toml`, with toolchain auto-download via foojay-resolver). All binary tools (Java, Node, hadolint, act, gitleaks, trivy) are pinned in `.mise.toml` and installed via a single `mise install` — the only version constants left in the Makefile are `GJF_VERSION` (JAR), `MERMAID_CLI_VERSION` and `PLANTUML_VERSION` (Docker images), since mise does not manage those asset classes
- **JVM args for FIPS**: `-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3` (configured in `application` block; tests run with `-Dsemeru.fips=false`)
- **Dependencies** managed via `gradle/libs.versions.toml` (Guava, JUnit Jupiter) and `gradle.properties` (Commons Lang, plugin versions)
- **JaCoCo** minimum coverage: 60%
- **Checkstyle** with custom rules at `config/checkstyle/checkstyle.xml` (120 char line limit, 50 line method limit, 800 line file limit)
- **hadolint** for Dockerfile linting (auto-installed via `deps-hadolint`; ignores configured in `.hadolint.yaml`)
- **OWASP Dependency-Check** fails build on CVSS >= 7.0; suppressions in `dependency-check-suppressions.xml`
- **Diagram lint** — `make mermaid-lint` uses [`minlag/mermaid-cli`](https://github.com/mermaid-js/mermaid-cli) to parse any inline Mermaid fenced blocks in markdown (short-circuits when none present); `make diagrams-check` uses [`plantuml/plantuml`](https://plantuml.com/) `-checkonly` to syntax-check `docs/diagrams/*.puml`. Both are prerequisites of `make static-check`.
- **Test pyramid** — this is a CLI tool, no HTTP/cluster surface, so e2e is the CI docker-job smoke test (runs the real image + greps stdout for FIPS status + OpenJCEPlusFIPS provider). Unit tests: `make test` (`FIPSValidatorTest`, sub-second, JVM-in-process). Integration: `make integration-test` (`FIPSValidatorRunnerIT`, spawn-JVM subprocess under real `-Dsemeru.fips` flags, ~5 s).

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
- **static-check** job: `make static-check` (format-check + lint + secrets + trivy-fs + mermaid-lint + diagrams-check) — runs first (cheapest, fail-fast)
- **build** job: `make build`, `make run` — runs after static-check passes (`needs: [static-check]`)
- **test** job: `make test`, `make coverage-check` — runs in parallel with build after static-check (`needs: [static-check]`)
- **integration-test** job: `make integration-test` (`FIPSValidatorRunnerIT` subprocess suite) — runs in parallel with build/test after static-check (`needs: [static-check]`)
- **docker** job: builds and scans the image on every push (Trivy image scan, smoke test, canonical two-build pattern with GHA cache). `push` and `cosign sign` steps are tag-gated (`startsWith(github.ref, 'refs/tags/')`). Requires `id-token: write` for cosign keyless OIDC. `needs: [build, test, integration-test]`
- **ci-pass** job: aggregate status gate (`if: always()`, `needs` all above) — use this as the branch-protection required check
- **concurrency**: superseded runs on the same branch are automatically cancelled
- Hybrid toolchain install in CI: `jdx/mise-action@v4` in `static-check` (needs hadolint + gitleaks + trivy from `.mise.toml`); `actions/setup-java@v5 distribution: semeru` in `build` / `test` / `integration-test` (Java-only, faster cold cache). `gradle/actions/setup-gradle@v6` handles Gradle caching. Local dev is 100% mise; the Makefile targets are agnostic to how binaries got on PATH.
- `workflow_call` trigger supports reuse from other workflows

Cleanup workflow (`.github/workflows/cleanup-runs.yml`): weekly cron that deletes old workflow runs (retains 7 days, minimum 5 runs).

**Note:** `actions/upload-artifact` is at v7 (hash `bbbca2dd`). Artifact uploads fail locally in act (protocol mismatch with act's artifact server), but `continue-on-error: true` ensures jobs still pass. Artifacts upload correctly on real GitHub Actions.

Run CI locally before pushing: `make ci` (mirrors the static-check → test → integration-test → coverage → build pipeline)
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

Deferred upgrade items. Last full review: 2026-04-14 (via `/upgrade-analysis`). Review periodically — resolve actionable items, remove stale ones.

### Open

- [ ] **FIPS profile hard expiry 2026-09-21** (~160 days) — Semeru JDK FIPS profile `OpenJCEPlusFIPS.FIPS140-3` expires on this date. App will refuse to start after. Needs a future Semeru release from IBM. Check: `make run` output for expiry warning. **Monitor monthly.**
- [ ] **Gradle 10 compatibility** — ben-manes versions plugin triggers deprecation warning. Watch for plugin update. Check: `./gradlew dependencyUpdates --warning-mode all`.
- [x] ~~**Wave 2 major action bumps**~~ — Applied 2026-04-14. `docker/metadata-action@v6`, `docker/build-push-action@v7`, `sigstore/cosign-installer@v4` (installs Cosign v3) all landed together. `make ci-run` verified clean through the non-tag-gated path; cosign sign itself still needs a real tag push to exercise fully (tracked in next-release checklist).
- [x] ~~**Remove `"nvm"` from Renovate `enabledManagers`**~~ — Resolved 2026-04-14 via `/renovate`. Also added `.mise.toml` custom manager; dropped native `mise` manager to avoid duplicate-PR risk from datasource mismatch; inline `# renovate:` comments are the single source of truth for `.mise.toml` pins.
- [ ] **SBOM / provenance opt-in** — docker job currently sets `sbom: false` + `provenance: false` per hardening decision. Revisit if SLSA L2 attestations become a compliance requirement; build-push-action v7 supports `provenance: mode=max`.
- [ ] **Portfolio version skew audit** — run `/upgrade-analysis portfolio` against `~/projects/` to catch drift in `act`, `hadolint`, `gitleaks`, `trivy`, Java Semeru, Gradle, and GitHub Action SHAs across the 20+ repos.
- [ ] **Java 25 LTS migration planning** — Java 25 LTS expected Sep 2025. Java 21 LTS supported through ~2031. Plan migration 2027–2028.
- [ ] **`commons-lang3` decoy dependency** — declared only to give `make cve-check` something to scan (see inline comment in `app/build.gradle`). If real runtime deps are added, remove or move into a dedicated `cveOnly` configuration so it doesn't leak into the shipped classpath.
- [ ] **Multi-arch Docker image** — amd64-only because IBM Semeru FIPS profile lacks certified arm64 variant as of 2026-04-14. Re-verify quarterly via `docker manifest inspect icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal`.
- [ ] **`actions/cache@v4` deprecation warning (transitive via `aquasecurity/trivy-action`)** — CI emits `Node.js 20 actions are deprecated` annotation on every run. Pin is inside `aquasecurity/trivy-action@0.35.0`, not directly referenceable from our workflow. Real failure deadline: 2026-09-16 (Node 20 removed from runners). Fix depends on upstream `aquasecurity/trivy-action` bumping its internal `actions/cache` pin — monitor their release notes; Renovate will pick up a newer `trivy-action` when one ships.

### Resolved

- [x] ~~**SDKMAN → mise migration**~~ — Completed 2026-04-14. All binary toolchain (Java, Node, hadolint, act, gitleaks, trivy) pinned in `.mise.toml` with Renovate annotations. `.nvmrc` dropped.
- [x] ~~**`JAVA_VER` not tracked by Renovate**~~ — Resolved 2026-04-14. Migrated from SDKMAN to mise; Java version pinned in `.mise.toml` with `datasource=java-version`.
- [x] ~~**Integration-test layer**~~ — Added 2026-04-14. `FIPSValidatorRunnerIT` spawns-JVM subprocess with real flags; Gradle `integrationTest` source set + task; CI job + Makefile target.
- [x] ~~**Docker image hardening**~~ — 2026-04-14. Trivy image scan + smoke test (incl. negative case) + cosign keyless OIDC signing + GHA cache + two-build pattern.
- [x] ~~**upload-artifact v4 → v7 migration**~~ — Completed 2026-04-03.
- [x] ~~**commons-math3 stale since 2016**~~ — Resolved 2026-04-03. Removed entirely.
- [x] ~~**Dockerfile missing syntax directive**~~ — Resolved 2026-04-05. Added `# syntax=docker/dockerfile:1`.
- [x] ~~**Renovate `docker-compose` manager without compose file**~~ — Resolved 2026-04-05. Removed from `enabledManagers`.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
