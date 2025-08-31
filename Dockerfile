FROM openjdk:21-jdk-slim
COPY target/hazelcast-demo-0.0.1-SNAPSHOT.jar app.jar
RUN mkdir -p /app/config
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
