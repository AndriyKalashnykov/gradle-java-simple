# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# Build stage - compile the application. $BUILDPLATFORM = native runner arch,
# maximizes build speed. Arch of the produced JARs is irrelevant (pure JVM).
FROM --platform=$BUILDPLATFORM gradle:9.8.2-jdk21@sha256:37110d25b7a0f866d07f7e61968347b83d2e0fd01bd6ddf74c9ae2ff04000691 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY dependency-check-suppressions.xml ./
COPY app app

# Build the application distribution (classes + dependency JARs)
RUN ./gradlew :app:installDist -x test -x checkstyleMain -x checkstyleTest

# Runtime stage - use FIPS-enabled Semeru runtime (IBM public registry).
# The runtime FROM defaults to $TARGETPLATFORM automatically — buildx's
# `platforms: linux/amd64` in the docker job controls single-arch amd64
# (Semeru FIPS profile has no certified arm64 variant as of 2026-04-14).
FROM icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal@sha256:22838fc0d0124b2d00491d4750a8f71cbe547122e908ce453a2d695a69debaef

WORKDIR /app

# Patch CVEs that the base image carries. The Semeru runtime image defaults
# to USER 1001, so flip back to root for microdnf, then return to 1001.
# CVE-2026-4878: libcap TOCTOU race; fixed in 2.48-10.el9_7.1.
# Refresh whenever Trivy flags a HIGH/CRITICAL fixed in the UBI 9 stream.
USER root
RUN microdnf update -y \
    && microdnf clean all \
    && rm -rf /var/cache/yum
USER 1001

# Copy application distribution (app JAR + dependency JARs only)
COPY --from=builder /build/app/build/install/app/lib /app/lib

# Set FIPS mode
ENV JAVA_OPTS="-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"

# Run FIPSValidatorRunner with FIPS configuration
CMD ["java", "-Dsemeru.fips=true", "-Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3", "-cp", "/app/lib/*", "org.example.FIPSValidatorRunner"]
