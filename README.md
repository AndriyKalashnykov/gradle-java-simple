# Gradle based Java project for general purpose testing 

## Pre-requisites

- [sdkman](https://sdkman.io/install)

  Install and use JDK 21

    ```bash
    sdk install java 21-tem
    sdk use java 21-tem
    ```
- [Apache Maven](https://maven.apache.org/install.html)

  Install Gradle 9.0.0

    ```bash
    sdk install gradle 9.0.0
    sdk use gradle 9.0.0
    ```
- [`GNU Make`](https://www.gnu.org/software/make/)

## Usage

Check for vulnerabilities:
```bash
make cve-check-dep
```

Run:
```bash
make run
```

### Help

```bash
make help
```