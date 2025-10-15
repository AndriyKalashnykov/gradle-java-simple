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

Run dependencies check for publicly disclosed vulnerabilities in application dependencies:
```bash
make cve-check
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

help              - List available tasks
check-env         - Check installed tools
clean             - Cleanup
test              - Run project tests
build             - Build project
run               - Run project
cve-check         - Run dependencies check for publicly disclosed vulnerabilities in application dependencies
coverage-generate - Run tests with coverage report
coverage-check    - Verify code coverage meets minimum threshold ( > 60%)
coverage-open     - Open code coverage report
```

## Semeru 21 FIPS

```bash
java -version
java -XshowSettings:properties -version 2>&1 | grep -i "java.home"
ls -la /usr/lib/jvm/ibm-semeru-open-21-jre/conf/security/
grep -i "OpenJCEPlus" /usr/lib/jvm/ibm-semeru-open-21-jre/conf/security/java.security
grep "^security.provider" /usr/lib/jvm/ibm-semeru-open-21-jre/conf/security/java.security
find / -name "*OpenJCEPlus*" -o -name "*FIPS*" 2>/dev/null
```

