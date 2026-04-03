# Build stage - compile the application
FROM --platform=linux/amd64 gradle:9.4.1-jdk21@sha256:7ca3db170906c970153cd3a576ddb42ec3cedc4e6f1dbb2228547e286fa5c3b4 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY dependency-check-suppressions.xml ./
COPY app app

# Build the application distribution (classes + dependency JARs)
RUN ./gradlew :app:installDist -x test -x checkstyleMain -x checkstyleTest

# Runtime stage - use FIPS-enabled Semeru runtime (IBM public registry)
FROM --platform=linux/amd64 icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal@sha256:d4906d134a4186905fd7a9af774c0c6feeb4eed8237405c6f039044548f94cbf

WORKDIR /app

# Copy application distribution (app JAR + dependency JARs only)
COPY --from=builder /build/app/build/install/app/lib /app/lib

USER 1001

# Set FIPS mode
ENV JAVA_OPTS="-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"

# Run FIPSValidatorRunner with FIPS configuration
CMD ["java", "-Dsemeru.fips=true", "-Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3", "-cp", "/app/lib/*", "org.example.FIPSValidatorRunner"]
