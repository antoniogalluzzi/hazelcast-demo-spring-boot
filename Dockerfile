# Multi-stage build for optimized image
FROM openjdk:17-jdk-slim as build
WORKDIR /app
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY src src
RUN chmod +x ./mvnw
RUN ./mvnw clean package -DskipTests

# Production image
FROM openjdk:17-jre-slim
WORKDIR /app
COPY --from=build /app/target/hazelcast-demo-*.jar app.jar

# Create non-root user for security
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --gid 1001 appuser
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
