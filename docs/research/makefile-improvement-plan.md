# Makefile Improvement Plan

**Date:** 2026-03-06
**Analyzed by:** Architect, Devil's Advocate, Builder, Code Reviewer agents (parallel)

---

## Executive Summary

The current Makefile has **critical correctness bugs**, **massive redundancy** (a single `make ci` runs `./gradlew clean` 10 times, builds 4 times, tests 3 times), and **~60 lines of dead code**. This plan addresses all issues in priority order.

---

## Phase 1: Critical Fixes (Correctness)

### 1.1 Add `.PHONY` Declarations

**Problem:** No `.PHONY` exists. Since Gradle creates a `build/` directory, `make build` can silently skip execution ("make: 'build' is up to date").

**Fix:**
```makefile
.PHONY: help check-env clean lint test build run \
        cve-check cve-db-update cve-db-purge \
        coverage-generate coverage-check coverage-open \
        docker-build docker-run docker-image docker-push \
        gradle-stop upgrade renovate-bootstrap renovate-validate \
        ci ci-docker tmux-session
```

### 1.2 Rewrite `build-deps-check` (Lines 86-101)

**Problems (all CRITICAL/HIGH):**
- `ifndef SDKMAN_DIR` is a Make parse-time directive, not a runtime shell check -- entire conditional logic is broken
- Each recipe line runs in a separate subshell -- `source` on line 90 and `export` on line 99 have zero effect
- Lines 99-100 are dead code
- `echo N | sdk install` is fragile; use `SDKMAN_AUTO_ANSWER=true` instead
- `SDKMAN_EXISTS` variable (line 16) carries a shell command as a value -- anti-pattern

**Fix:** Replace with a single `bash -c` block using `command -v` checks:

```makefile
#check-env: @ Verify and install required build dependencies
check-env:
	@bash -c '\
	  set -euo pipefail; \
	  ok()   { printf "\033[32m[OK]\033[0m    %s\n" "$$1"; }; \
	  warn() { printf "\033[33m[WARN]\033[0m  %s\n" "$$1"; }; \
	  fail() { printf "\033[31m[FAIL]\033[0m  %s\n" "$$1"; exit 1; }; \
	  \
	  echo "=== Checking build dependencies ==="; \
	  \
	  # curl (required) \
	  command -v curl >/dev/null 2>&1 && ok "curl" || \
	    fail "curl not found. Install via your package manager."; \
	  \
	  # SDKMAN (auto-install if missing) \
	  export SDKMAN_DIR="$${SDKMAN_DIR:-$$HOME/.sdkman}"; \
	  if [[ -s "$$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then \
	    source "$$SDKMAN_DIR/bin/sdkman-init.sh"; \
	    ok "SDKMAN"; \
	  else \
	    warn "SDKMAN not found -- installing..."; \
	    curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
	    source "$$SDKMAN_DIR/bin/sdkman-init.sh"; \
	    ok "SDKMAN installed"; \
	  fi; \
	  \
	  export SDKMAN_AUTO_ANSWER=true; \
	  \
	  # Java (auto-install via sdkman) \
	  sdk install java "$(JAVA_VER)" 2>/dev/null || true; \
	  sdk use java "$(JAVA_VER)"; \
	  ok "Java $(JAVA_VER)"; \
	  \
	  # Gradle (auto-install via sdkman) \
	  sdk install gradle "$(GRADLE_VER)" 2>/dev/null || true; \
	  sdk use gradle "$(GRADLE_VER)"; \
	  ok "Gradle $(GRADLE_VER)"; \
	  \
	  # Optional: Docker \
	  if command -v docker >/dev/null 2>&1; then \
	    ok "Docker (optional)"; \
	  else \
	    warn "Docker not found (needed for: docker-build, docker-run, docker-push)"; \
	  fi; \
	  \
	  echo "=== Done ==="; \
	'
```

**Key changes:**
- Merge `build-deps-check` and `check-env` into one target (they were redundant)
- Single subshell preserves `source`d environment across all steps
- `SDKMAN_AUTO_ANSWER=true` replaces fragile `echo N |` pipe
- `sdk install ... || true` handles already-installed case
- `command -v` for detection (POSIX, reliable)
- Required deps fail, optional deps warn

### 1.3 Add `.SHELLFLAGS` for Error Propagation

```makefile
.SHELLFLAGS := -eu -o pipefail -c
```

### 1.4 Fix `gradle-stop` Silent Failure (Line 176)

```makefile
gradle-stop:
	@$(GRADLE) --stop
	@pkill -f '.*GradleDaemon.*' || true
```

---

## Phase 2: Eliminate Redundancy (Performance)

### 2.1 Remove `clean` From Individual Targets

**Problem:** `./gradlew clean` appears in 6 targets. The dependency chain `run -> test -> build` causes 3 clean+compile cycles for a single `make run`. A full `make ci` runs **10 cleans, 4 builds, 3 test suites**.

**Fix:** Remove `clean` from all targets except the dedicated `clean` target. Rely on Gradle's incremental build.

| Target | Before | After |
|--------|--------|-------|
| `build` | `./gradlew clean build` | `$(GRADLE) build` |
| `test` | `./gradlew clean :app:test ...` | `$(GRADLE) :app:test ...` |
| `run` | `./gradlew clean :app:run ...` | `$(GRADLE) :app:run ...` |
| `cve-check` | `./gradlew clean :app:dependencyCheckAnalyze ...` | `$(GRADLE) :app:securityScan ...` |
| `coverage-generate` | `./gradlew clean test jacocoTestReport` | `$(GRADLE) test jacocoTestReport` |

### 2.2 Break Deep Dependency Chains

**Problem:** `run` depends on `test` depends on `build` depends on `check-env`. Each target rebuilds from scratch.

**Fix:** Make targets self-contained. Let `ci` be the orchestrator.

```makefile
build: check-env
	@$(GRADLE) build

test:
	@$(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3

run:
	@$(GRADLE) :app:run $(NO_CACHE) --warning-mode all

lint:
	@$(GRADLE) checkstyleMain checkstyleTest

coverage-generate:
	@$(GRADLE) test jacocoTestReport
	@echo "Coverage report: ./app/build/reports/jacoco/test/html/index.html"

coverage-check: coverage-generate
	@$(GRADLE) jacocoTestCoverageVerification
```

### 2.3 Restructure `ci` as Linear Pipeline

```makefile
ci: check-env
	@echo "=== CI Step 1/5: Build ==="
	@$(GRADLE) clean build
	@echo "=== CI Step 2/5: Lint ==="
	@$(GRADLE) checkstyleMain checkstyleTest
	@echo "=== CI Step 3/5: Test ==="
	@$(GRADLE) :app:test --tests "org.example.FIPSValidatorTest" --info \
	  -Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3
	@echo "=== CI Step 4/5: Coverage ==="
	@$(GRADLE) jacocoTestReport jacocoTestCoverageVerification
	@echo "=== CI Step 5/5: Run ==="
	@$(GRADLE) :app:run $(NO_CACHE) --warning-mode all
	@echo "=== CI Complete ==="
```

**Result:** From ~12 Gradle invocations with 10 cleans down to **5 Gradle invocations with 1 clean**.

### 2.4 Fix `cve-check` Double Analysis

**Problem (line 134):** Calls both `dependencyCheckAnalyze` and `securityScan`, but `securityScan` already depends on `dependencyCheckAnalyze` in `build.gradle`. Analysis runs twice.

**Fix:** Call only `securityScan`:
```makefile
cve-check:
	@$(GRADLE) :app:securityScan $(NO_CACHE) --warning-mode all
```

---

## Phase 3: Remove Dead Code (Conciseness)

### 3.1 Remove Unused Variables

| Variable | Line | Used? | Action |
|----------|------|-------|--------|
| `SDKMAN_EXISTS` | 16 | Broken pattern | Remove |
| `NODE_EXISTS` | 17 | Never | Remove |
| `IS_LINUX` | 20 | Never | Remove |
| `IS_FREEBSD` | 21 | Never | Remove |
| `IS_WINDOWS` | 22 | Never | Remove |
| `IS_AMD64` | 23 | Never | Remove |
| `IS_AARCH64` | 24 | Never | Remove |
| `IS_RISCV64` | 25 | Never | Remove |

### 3.2 Replace 57 Lines of Platform Detection With 2 Lines

Only `IS_DARWIN` is used (line 155, for `coverage-open`). Replace lines 19-75 with:

```makefile
UNAME_S := $(shell uname -s)
IS_DARWIN := $(if $(filter Darwin,$(UNAME_S)),1,0)
```

### 3.3 Remove Dead Lines 99-100

Already handled by the `check-env` rewrite in Phase 1.

---

## Phase 4: Extract Variables & Standardize (Maintainability)

### 4.1 Extract Common Variables

```makefile
GRADLE   := ./gradlew
NO_CACHE := --no-configuration-cache
```

Replace all 13 occurrences of `./gradlew` with `$(GRADLE)` and 3 occurrences of `--no-configuration-cache` with `$(NO_CACHE)`.

### 4.2 Standardize `@` Prefix

Pick `@` (no space) consistently. Replace all `@ ./gradlew` with `@$(GRADLE)`.

### 4.3 Fix Help Comment Format

| Target | Issue | Fix |
|--------|-------|-----|
| `cve-db-update` (L136) | Missing `:` after name | `#cve-db-update: @ Update vulnerability database` |
| `cve-db-purge` (L140) | Missing `@` delimiter | `#cve-db-purge: @ Purge local database` |
| `build-deps-check` | No comment | Merged into `check-env` |
| `tmux-session` | No comment | Add `#tmux-session: @ Launch tmux session with Claude` |

### 4.4 Remove `@clear` From Help Target (Line 79)

Destroys terminal scrollback. Hostile in CI/scripts.

### 4.5 Add Docker Guard Target

```makefile
require-docker:
	@command -v docker >/dev/null 2>&1 || \
	  { echo "Error: Docker required. Install: https://docs.docker.com/get-docker/"; exit 1; }

docker-build: require-docker
	...
```

### 4.6 Fix `clean` Target (Line 113)

**Problem:** `rm -rf .gradle` deletes the dependency-check database at `.gradle/dependency-check-data`.

```makefile
clean:
	@$(GRADLE) clean
	@rm -rf build app/build
```

---

## Phase 5: Nice-to-Have Improvements

### 5.1 Add `GRADLE_VER` Validation or Remove It

`GRADLE_VER := 9.0.0` (line 8) can diverge from `gradle-wrapper.properties`. Either:
- Remove it (let the wrapper control the version)
- Add a validation step comparing against wrapper properties

### 5.2 Address `tmux-session` Security

Hardcoded `--dangerously-skip-permissions` (line 222). Options:
- Remove the flag (use default interactive mode)
- Add confirmation prompt
- Make it opt-in: `UNSAFE ?= 0`

### 5.3 Fix `renovate-bootstrap` / `renovate-validate` Subshell Issue

nvm sourced in `renovate-bootstrap` is invisible to `renovate-validate` because they run in separate subshells. Combine into single target or use `bash -c` block.

### 5.4 Add `NVD_API_KEY` Check to `cve-check`

```makefile
cve-check:
	@[ -n "$$NVD_API_KEY" ] || echo "Warning: NVD_API_KEY not set; CVE database updates may fail"
	@$(GRADLE) :app:securityScan $(NO_CACHE)
```

---

## Proposed Final Makefile Structure

```
Variables:         ~15 lines  (GRADLE, NO_CACHE, versions, docker, platform)
.PHONY:            ~4 lines
Help:              ~6 lines
check-env:         ~40 lines  (single bash -c block, replaces build-deps-check)
Build targets:     ~25 lines  (clean, build, test, run, lint)
Coverage targets:  ~10 lines  (generate, check, open)
CVE targets:       ~10 lines  (check, db-update, db-purge)
Docker targets:    ~15 lines  (require-docker, build, run, image, push)
CI targets:        ~15 lines  (ci, ci-docker)
Utility targets:   ~15 lines  (gradle-stop, upgrade, renovate, tmux)
─────────────────────────────
Total:             ~155 lines (down from 223)
```

---

## Impact Summary

| Metric | Before | After |
|--------|--------|-------|
| Lines of code | 223 | ~155 |
| Dead code lines | ~60 | 0 |
| `make ci` Gradle invocations | ~12 | 5 |
| `make ci` clean cycles | 10 | 1 |
| `make ci` full builds | 4 | 1 |
| `make ci` test runs | 3 | 1 |
| `.PHONY` declarations | 0 | All targets |
| Unused variables | 8 | 0 |
| `build-deps-check` bugs | 6 | 0 |
| Help entries missing | 4 | 0 |

---

## Agent Contributions

| Agent | Focus | Key Findings |
|-------|-------|-------------|
| **Architect** | Structure, dependency chains, CI alignment | 10 clean cycles in `make ci`; deep dependency chains; CI/local divergence |
| **Devil's Advocate** | Risks, edge cases, broken logic | `ifndef` is parse-time not runtime; subshell isolation kills `source`/`export`; `SDKMAN_EXISTS` anti-pattern |
| **Builder** | Dependency installation best practices | `SDKMAN_AUTO_ANSWER=true`; `command -v` over `which`; hybrid check-and-install strategy; `require-docker` guard pattern |
| **Code Reviewer** | Code quality, unused vars, consistency | 8 unused variables; missing `.PHONY`; `@` spacing inconsistency; `tmux-session` security; help regex misses 3 targets |
