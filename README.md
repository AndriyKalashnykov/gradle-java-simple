[![ci](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml/badge.svg)](https://github.com/AndriyKalashnykov/gradle-java-simple/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/gradle-maven-simple.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/gradle-maven-simple/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
# Gradle based Java project for general purpose testing 

## Pre-requisites

- [sdkman](https://sdkman.io/install)

  Install and use JDK

    ```bash
    sdk install java 21-tem
    sdk use java 21-tem
    ```
- [gradle](https://docs.gradle.org/current/userguide/installation.html)

  Install Gradle

    ```bash
    sdk install gradle 9.0.0
    sdk use gradle 9.0.0
    ```
- [`GNU Make`](https://www.gnu.org/software/make/)

## Usage

Check pre-reqs:
```bash
make check-env
```

Run dependencies check - publicly disclosed vulnerabilities in application dependencies:
```bash
make cve-dep-check
```

Run:
```bash
make run
```

### Help

```bash
make help
```

```text
Usage: make COMMAND

Commands :

help          - List available tasks
clean         - Cleanup
check-env     - Check environment variables and installed tools
cve-dep-check - Dependency Check Analysis and a Custom Security Scan task
test          - Test project
j-generate    - Run tests with coverage report
j-check       - Verify code coverage meets minimum threshold ( > 60%)
j-open        - Open Jacoco report
build         - Build project
run           - Run project
```