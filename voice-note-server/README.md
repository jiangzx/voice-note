# voice-note-server

Voice Note AI Gateway — ASR Token Broker & LLM Router for the 随口记 (SuiKouJi) app.

## Quick Start

```bash
# Set your DashScope API key
export DASHSCOPE_API_KEY=sk-xxx

# Run with Gradle
./gradlew bootRun --args='--spring.profiles.active=dev'
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/asr/token` | Generate temporary ASR token |
| POST | `/api/v1/llm/parse-transaction` | Parse natural language into transaction |
| GET | `/actuator/health` | Health check |

## Configuration

All configuration is externalized via environment variables or `application.yml`.

| Variable | Description | Default |
|----------|-------------|---------|
| `DASHSCOPE_API_KEY` | DashScope API key (required) | — |
| `SPRING_PROFILES_ACTIVE` | Active profile | `default` |

## Docker

```bash
# Build
./gradlew bootJar
docker build -t voice-note-server .

# Run
docker run -p 8080:8080 -e DASHSCOPE_API_KEY=sk-xxx voice-note-server
```
