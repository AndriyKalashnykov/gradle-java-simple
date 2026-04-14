# syntax=docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

# Build stage - compile the application. $BUILDPLATFORM = native runner arch,
# maximizes build speed. Arch of the produced JARs is irrelevant (pure JVM).
FROM --platform=$BUILDPLATFORM gradle:9.4.1-jdk21@sha256:7ca3db170906c970153cd3a576ddb42ec3cedc4e6f1dbb2228547e286fa5c3b4 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY dependency-check-suppressions.xml ./
COPY app app

# Build the application distribution (classes + dependency JARs)
RUN ./gradlew :app:installDist -x test -x checkstyleMain -x checkstyleTest

# Runtime stage - use FIPS-enabled Semeru runtime (IBM public registry).
# $TARGETPLATFORM is controlled by buildx `platforms:` input — pinned to
# linux/amd64 in CI (Semeru FIPS profile has no certified arm64 variant).
FROM --platform=$TARGETPLATFORM icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal@sha256:e8f19758efe9f556c3cf7a658fd5e551f5def2862a9f1b96344625e188f9ed3f

WORKDIR /app

# Copy application distribution (app JAR + dependency JARs only)
COPY --from=builder /build/app/build/install/app/lib /app/lib

USER 1001

# Set FIPS mode
ENV JAVA_OPTS="-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"

# Run FIPSValidatorRunner with FIPS configuration
CMD ["java", "-Dsemeru.fips=true", "-Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3", "-cp", "/app/lib/*", "org.example.FIPSValidatorRunner"]
