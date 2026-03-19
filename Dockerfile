# Build stage - compile the application
FROM --platform=linux/amd64 gradle:9.4.1-jdk21 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY dependency-check-suppressions.xml ./
COPY app app

# Build the application
RUN ./gradlew :app:build -x test -x checkstyleMain -x checkstyleTest

# Runtime stage - use FIPS-enabled Semeru runtime (IBM public registry)
FROM --platform=linux/amd64 icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal@sha256:8e7b0114fefdc11491ed5fe3b5c64248c03896ee17f92a305195cb74eab711d7

WORKDIR /app

USER root

# Copy compiled classes and dependencies
COPY --from=builder /build/app/build/classes/java/main /app/classes
COPY --from=builder /build/app/build/libs /app/libs
COPY --from=builder /root/.gradle/caches /root/.gradle/caches

USER 1001

# Set FIPS mode
ENV JAVA_OPTS="-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"

# Build classpath and run FIPSValidatorRunner
CMD CLASSPATH="/app/classes"; \
    for jar in $(find /root/.gradle/caches/modules-2/files-2.1 -name "*.jar" 2>/dev/null); do \
        CLASSPATH="$CLASSPATH:$jar"; \
    done; \
    java -Dsemeru.fips=true \
         -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3 \
         -cp "$CLASSPATH" \
         org.example.FIPSValidatorRunner
