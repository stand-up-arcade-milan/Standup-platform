# Build the executable jar in a Maven/JDK image; developers need Docker, not local Maven.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

COPY pom.xml ./
COPY src ./src
RUN mvn -B -DskipTests package

# Keep only the JRE and the application in the runtime image.
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /workspace/target/standup-platform-api-*.jar /app/app.jar

# The app only needs to listen on 8080 and read its configuration from Compose.
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
