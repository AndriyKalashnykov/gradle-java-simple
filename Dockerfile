# Build stage - compile the application
FROM --platform=linux/amd64 gradle:9.4.0-jdk21@sha256:a45bbf6995c17e646e4e0260ca2af53e6ec6424ff9b03896fef3a8ce91a57891 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY dependency-check-suppressions.xml ./
COPY app app

# Build the application
RUN ./gradlew :app:build -x test -x checkstyleMain -x checkstyleTest

# Runtime stage - use FIPS-enabled Semeru runtime (IBM public registry)
FROM --platform=linux/amd64 icr.io/appcafe/ibm-semeru-runtimes:open-21-jre-ubi9-minimal@sha256:8d7b75cd3691006de922c27ad656d4258af22bdde2911f6769fdc90912d8b28e

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
