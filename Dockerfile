# Use the Eclipse Temurin base image
FROM eclipse-temurin:17-jdk-alpine

# Expose the application port
EXPOSE 8082

# Set the application home environment variable
ENV APP_HOME=/usr/src/app

# Copy the application JAR file into the container
COPY target/*.jar $APP_HOME/app.jar

# Set the working directory
WORKDIR $APP_HOME

# Run the application
CMD ["java", "-jar", "app.jar"]
