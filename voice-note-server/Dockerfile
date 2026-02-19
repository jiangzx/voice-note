FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

COPY build/libs/voice-note-server-*.jar app.jar

RUN mkdir -p /app/logs

VOLUME /app/logs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
