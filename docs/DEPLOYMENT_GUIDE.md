# 随口记 (SuiKouJi) — 生产部署教程

本文档覆盖从开发到生产的完整配置修改清单、Docker 部署流程和安全加固建议。

---

## 目录

1. [部署架构概览](#1-部署架构概览)
2. [生产配置修改清单](#2-生产配置修改清单)
3. [Server 部署](#3-server-部署)
4. [Client 发布](#4-client-发布)
5. [安全加固](#5-安全加固)
6. [监控与运维](#6-监控与运维)
7. [配置参数速查表](#7-配置参数速查表)
8. [客户端语音错误码（ASR Token）](#8-客户端语音错误码asr-token)
9. [客户端语音错误码（LLM 解析/纠错）](#9-客户端语音错误码llm-解析纠错)

---

## 1. 部署架构概览

```
┌──────────────────┐     HTTPS      ┌─────────────────────┐     HTTPS     ┌─────────────┐
│  Flutter Client  │ ──────────────▶ │  voice-note-server  │ ────────────▶ │  DashScope  │
│  (iOS/Android)   │                 │  (Spring Boot)      │               │  (ASR/LLM)  │
└──────────────────┘                 └─────────────────────┘               └─────────────┘
        │                                    │
        │ SQLite (本地)                       │ 无状态
        ▼                                    ▼
   本地数据库                           可水平扩展
```

**关键设计**：
- Server 无状态 → 可水平扩展，前面加 Load Balancer
- Client 本地优先 → 离线仍可使用（本地 NLP + 本地数据库）
- Server 仅做 AI Gateway（Token Broker + LLM Proxy）→ 计算开销极小

---

## 2. 生产配置修改清单

### 2.1 Server 配置修改

需要修改的文件：`voice-note-server/src/main/resources/application.yml`

| 配置项 | 开发默认值 | 生产推荐值 | 说明 |
|--------|-----------|-----------|------|
| `server.port` | `8080` | `8080`（由反向代理转发） | 内部端口，不直接暴露 |
| `dashscope.api-key` | `${DASHSCOPE_API_KEY}` | `${DASHSCOPE_API_KEY}` | **通过环境变量注入，不要硬编码** |
| `dashscope.asr.token-ttl-seconds` | `300` | `120` | 缩短 Token 有效期提高安全性 |
| `cors.allowed-origins` | `*` | `https://api.suikouji.com` | 限制 CORS 来源，多个用逗号分隔 |
| `rate-limit.asr.tokens-per-minute` | `30` | 根据用户量调整 | 单 IP 限流，防止滥用 |
| `rate-limit.llm.tokens-per-minute` | `60` | 根据用户量调整 | 单 IP 限流 |
| `rate-limit.trusted-proxies` | 无 | `127.0.0.1` | 反向代理 IP，用于正确解析客户端真实 IP |
| `management.endpoint.health.show-details` | `when-authorized` | `never` | 隐藏健康详情 |
| 日志级别 | `DEBUG` | `INFO` | 由 `logback-spring.xml` 管理（prod profile 自动 INFO） |

**生产配置文件 `application-prod.yml`（已存在）**：

```yaml
# voice-note-server/src/main/resources/application-prod.yml

# API Key 认证 — 生产环境必须启用
api-auth:
  enabled: true
  key: ${API_AUTH_KEY}    # 通过环境变量注入

# CORS — 限制允许的来源域名
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS:https://api.suikouji.com}

dashscope:
  asr:
    token-ttl-seconds: 120  # 缩短 Token 有效期

rate-limit:
  asr:
    tokens-per-minute: 60
    burst-capacity: 60
  llm:
    tokens-per-minute: 120
    burst-capacity: 120
  trusted-proxies: ${RATE_LIMIT_TRUSTED_PROXIES:127.0.0.1}  # 反向代理 IP

management:
  endpoint:
    health:
      show-details: never   # 隐藏内部详情

# All logging levels managed by logback-spring.xml
```

### 2.2 Client 配置修改

| 位置 | 开发默认值 | 生产修改 | 说明 |
|------|-----------|---------|------|
| `api_config.dart` `_defaultBaseUrl` | `http://localhost:8080` | `https://api.suikouji.com` | 生产服务器地址 |
| `android/app/build.gradle.kts` `applicationId` | `com.spark.suikouji` | `com.suikouji.app`（你的包名） | Android 应用 ID |
| iOS `Bundle Identifier` | `com.spark.suikouji` | `com.suikouji.app` | iOS 包标识 |
| iOS `Info.plist` | — | 需添加 `NSMicrophoneUsageDescription` | 麦克风权限描述（语音功能必须） |
| App 内设置 → API Key | 空 | 与 Server `API_AUTH_KEY` 一致 | 客户端认证密钥 |

**修改 `api_config.dart`**：

```dart
// voice-note-client/lib/core/network/api_config.dart
static const _defaultBaseUrl = 'https://api.suikouji.com';  // ← 改为生产地址
```

**iOS 麦克风权限**（`ios/Runner/Info.plist`）：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来进行语音记账</string>
```

**客户端 API Key**：生产环境 Server 启用 API Key 认证后，用户需在 App「设置」→「高级设置」→「API Key」中填入对应密钥。请求会自动在 `X-API-Key` header 中携带。

### 2.3 Docker Compose 配置

文件：`deploy/docker-compose.yml`

```yaml
services:
  server:
    build:
      context: ../voice-note-server
      dockerfile: Dockerfile
    ports:
      - "${SERVER_PORT:-8080}:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE:-prod}   # 默认 prod
      - DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY}
      - API_AUTH_KEY=${API_AUTH_KEY}
      - CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-https://api.suikouji.com}
      - RATE_LIMIT_TRUSTED_PROXIES=${RATE_LIMIT_TRUSTED_PROXIES:-127.0.0.1}
      - LOG_DIR=/app/logs
    volumes:
      - ${LOG_DIR:-./logs}:/app/logs    # Persist log files to host
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 768M
```

> **提示**：所有环境变量均可通过 `deploy/.env` 文件注入（见 [3.2 节](#32-docker-compose-部署)），无需修改 `docker-compose.yml` 本身。开发模式只需在 `.env` 中设置 `SPRING_PROFILES_ACTIVE=dev`。

---

## 3. Server 部署

### 3.1 Docker 部署（推荐）

```bash
# 1. 构建 JAR
cd voice-note-server
./gradlew bootJar

# 2. 构建 Docker 镜像
docker build -t voice-note-server:latest .

# 3. 运行容器
docker run -d \
  --name voice-note-server \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DASHSCOPE_API_KEY=sk-你的Key \
  -e API_AUTH_KEY=你的认证密钥 \
  -e CORS_ALLOWED_ORIGINS=https://api.suikouji.com \
  -e RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1 \
  -e JAVA_OPTS="" \
  -v ./logs:/app/logs \
  --restart unless-stopped \
  voice-note-server:latest
```

### 3.2 Docker Compose 部署

```bash
cd deploy

# 设置环境变量（或创建 .env 文件）
export DASHSCOPE_API_KEY=sk-你的Key

# 启动
docker compose up -d

# 查看日志
docker compose logs -f server

# 停止
docker compose down
```

**创建 `.env` 文件**（推荐，避免命令行泄露 Key）：

```bash
# 从模板复制
cp .env.example .env

# 编辑填入实际值
vim .env
```

`.env` 文件示例：

```bash
# deploy/.env（⚠️ 此文件不要提交到 Git）
DASHSCOPE_API_KEY=sk-你的实际Key
API_AUTH_KEY=你的自定义认证密钥
CORS_ALLOWED_ORIGINS=https://api.suikouji.com
RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1
# SPRING_PROFILES_ACTIVE=dev    # 取消注释可切换到开发模式
# JAVA_OPTS=-Xms128m -Xmx256m   # 自定义 JVM 参数
# LOG_DIR=./logs                 # 日志文件输出目录
```

> 完整变量说明见 `deploy/.env.example`（可安全提交到 Git）。

### 3.3 裸机部署（JAR 直接运行）

```bash
# 构建
cd voice-note-server
./gradlew bootJar

# 运行
java -jar build/libs/voice-note-server-*.jar \
  --spring.profiles.active=prod
```

### 3.4 反向代理配置（Nginx 示例）

```nginx
server {
    listen 443 ssl http2;
    server_name api.suikouji.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Request-ID $request_id;

        # WebSocket support (if needed for future features)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health check endpoint (for load balancer)
    location /actuator/health {
        proxy_pass http://127.0.0.1:8080;
        access_log off;
    }
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name api.suikouji.com;
    return 301 https://$server_name$request_uri;
}
```

---

## 4. Client 发布

### 4.1 Android APK / AAB

```bash
cd voice-note-client

# 生成 release APK
flutter build apk --release

# 生成 App Bundle（Google Play 推荐）
flutter build appbundle --release
```

产物位置：
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

**签名配置**：发布前需配置签名密钥，详见 [Flutter Android 部署文档](https://docs.flutter.dev/deployment/android)。

### 4.2 iOS

```bash
cd voice-note-client

# 构建（需在 macOS 上运行）
flutter build ios --release
```

后续通过 Xcode → Archive → Upload to App Store Connect 完成发布。

### 4.3 发布前检查清单

- [ ] `api_config.dart` 中 `_defaultBaseUrl` 已改为生产地址
- [ ] `applicationId` / `Bundle Identifier` 已更换为正式包名
- [ ] iOS `Info.plist` 已添加 `NSMicrophoneUsageDescription` 麦克风权限描述
- [ ] App 图标和启动页已替换为正式素材
- [ ] 签名密钥已配置（Android keystore / iOS 证书）
- [ ] `flutter build` 无编译错误
- [ ] 客户端已配置 API Key（与生产 Server 的 `API_AUTH_KEY` 一致）
- [ ] 真机上测试完整流程通过（语音识别、键盘输入、保存、离线模式、TTS 播报）

---

## 5. 安全加固

### 5.1 API Key 管理

| 做 | 不做 |
|----|------|
| 通过环境变量注入 Key | 硬编码在代码/配置文件中 |
| 使用子账号 Key 限制权限 | 使用主账号 Key |
| 定期轮换 Key | 长期不更换 |
| 生产 Key 只存在部署环境 | 在聊天/邮件中传递 Key |

### 5.2 API 接口认证

Server 内置 `X-API-Key` Header 认证拦截器（`ApiKeyInterceptor`）：

- **开发模式**：默认关闭（`api-auth.enabled=false`）
- **生产模式**：`application-prod.yml` 自动启用，通过 `API_AUTH_KEY` 环境变量注入密钥
- **作用范围**：所有 `/api/**` 端点
- **拦截优先级**：API Key 校验 → Rate Limit → 业务逻辑

客户端在「设置 → API Key」配置密钥后，所有请求自动携带 `X-API-Key` header。

### 5.3 CORS

Server 内置 CORS 配置（`CorsProperties` + `WebMvcConfig`），控制哪些来源域名可以跨域访问 API：

- **开发模式**：默认 `*`（允许所有来源），方便本地调试
- **生产模式**：通过 `CORS_ALLOWED_ORIGINS` 环境变量限制为实际域名
- **作用范围**：所有 `/api/**` 端点
- **允许方法**：`GET`、`POST`、`OPTIONS`
- **允许 Headers**：`*`（所有请求头）
- **预检缓存**：3600 秒（1 小时）
- **多域名支持**：用逗号分隔，如 `https://app.suikouji.com,https://admin.suikouji.com`

```yaml
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS:https://api.suikouji.com}
```

### 5.4 Rate Limiting

Server 已内置基于 IP 的 Token Bucket 限流（Bucket4j）。生产环境调整限流参数：

```yaml
rate-limit:
  asr:
    tokens-per-minute: 60     # ASR Token 请求 / 分钟 / IP
    burst-capacity: 60
  llm:
    tokens-per-minute: 120    # LLM 解析请求 / 分钟 / IP
    burst-capacity: 120
  trusted-proxies: ${RATE_LIMIT_TRUSTED_PROXIES:127.0.0.1}
```

**Trusted Proxies**：当 Server 部署在 Nginx/ALB 等反向代理后面时，需要配置 `trusted-proxies` 让限流器正确解析客户端真实 IP（通过 `X-Forwarded-For` / `X-Real-IP` header）。未配置时，所有请求会被识别为同一代理 IP，导致限流误判。

**IP 解析策略**：为防止 `X-Forwarded-For` 伪造攻击，Server 使用 **右侧优先** 策略 — 取 `X-Forwarded-For` 中最后一个 IP（由受信任代理追加的真实客户端 IP）。这与 Nginx 默认的 `$proxy_add_x_forwarded_for` 行为兼容。

### 5.5 HTTPS

- **必须**通过 Nginx/CDN 配置 HTTPS
- Client `_defaultBaseUrl` 使用 `https://` 前缀
- DashScope 调用已经是 HTTPS

### 5.6 Token 安全

- ASR 临时 Token 生产环境 TTL 建议缩短至 120 秒（默认 300 秒）
- Token 仅用于 ASR WebSocket 连接，不泄露主 API Key

---

## 6. 监控与运维

### 6.1 健康检查

```bash
# 基础健康
curl https://api.suikouji.com/actuator/health
# {"status":"UP"}

# Actuator 端点（管理用）
# /actuator/health — 健康状态
# /actuator/info   — 应用信息
# /actuator/metrics — 指标（响应时间、JVM 等）
```

### 6.2 日志

**日志格式**：所有日志行包含 `[requestId]` 关联 ID，便于追踪单次请求的完整链路。关联 ID 来源于客户端传入的 `X-Request-ID` header，未传入时自动生成 8 位短 UUID。Server 会对传入的 ID 进行安全处理（仅保留 `[a-zA-Z0-9\-_.]` 字符，最长 64 字符）。

**端到端追踪**：`X-Request-ID` 会自动传播到上游 DashScope API 调用中，便于联合排查外部服务问题。DashScope API 调用内置 5xx 错误自动重试（最多 2 次，指数退避从 500ms 开始），重试日志标记为 WARN 级别。

```
2026-02-18 10:30:45.123  INFO [main] [a1b2c3d4] c.s.server.asr.AsrTokenService : ASR token generated: model=qwen3-asr-flash-realtime, durationMs=120
```

**日志输出**：生产环境同时输出到控制台和滚动文件（`logs/voice-note-server.log`）。可通过 `LOG_DIR` 环境变量自定义日志目录。

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 单文件上限 | 50MB | 超过后自动滚动 |
| 保留天数 | 30 天 | 自动清理过期日志 |
| 总容量上限 | 1GB | 超过后清理最早的日志 |
| 文件格式 | `.log.gz` | 历史日志自动 gzip 压缩 |

```bash
# Docker 容器实时查看
docker logs -f voice-note-server

# 按关联 ID 过滤
docker logs voice-note-server 2>&1 | grep "a1b2c3d4"

# 最近 100 行
docker logs --tail 100 voice-note-server

# 裸机部署查看文件日志
tail -f logs/voice-note-server.log

# 搜索特定请求链路
grep "a1b2c3d4" logs/voice-note-server*.log*
```

关键日志事件：
- `ASR token generated: model=…, durationMs=…` — Token 发放成功及耗时
- `DashScope call success: model=…, durationMs=…, responseChars=…` — LLM 调用成功
- `Primary model failed, trying fallback` — 主模型失败，切换备用模型
- `Both models failed` — 主备模型均失败（ERROR 级别）
- `Rate limit exceeded: clientIp=…, path=…` — 限流触发（WARN 级别）
- `Retrying DashScope: attempt=…, error=…` — DashScope 5xx 自动重试（WARN 级别）
- `Upstream API error with model=…: status=…` — 上游服务异常（不记录响应体，防止数据泄露）
- `CORS configured: allowedOrigins=…` — 启动时 CORS 配置确认
- `Loaded prompt template: name=…` — Prompt 模板加载

### 6.3 性能调优

**JVM 参数**：Dockerfile 内置 G1GC + `MaxRAMPercentage=75%` + `UseStringDeduplication`，适合容器环境。如需自定义可通过 `JAVA_OPTS` 环境变量追加或覆盖。

**WebClient 连接池**：DashScope API 调用使用独立连接池（最大 50 连接，空闲 30s 回收，生命周期 5 分钟），避免连接泄漏和过度创建。

**DashScope 5xx 重试**：LLM 调用内置指数退避重试（最多 2 次重试，基础延迟 500ms），仅对 5xx 服务端错误触发。失败后仍会进入 fallback 模型流程。

**ASR Token 缓存**：Server 端缓存 ASR Token，避免每次请求都调用 DashScope Token API。Token 在过期前 30 秒自动失效。

**客户端数据库索引**：`transactions` 表已创建 4 个索引（`date+type`、`category_id`、`account_id`、`is_draft`），加速统计聚合和筛选查询。

**SQL 聚合优化**：收支汇总（`getSummary`、`getPeriodSummary`）使用 SQL `SUM()` + `GROUP BY` 聚合，避免将全部行加载到内存再求和。

### 6.4 扩容

Server 无状态，水平扩展只需：
1. 启动多个容器实例
2. 在 Nginx/ALB 配置负载均衡

---

## 7. 配置参数速查表

### Server 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `DASHSCOPE_API_KEY` | ✅ | DashScope API Key（启动时校验，缺失则报错退出） |
| `API_AUTH_KEY` | 生产 ✅ | 客户端认证密钥（`X-API-Key` header 校验值） |
| `API_AUTH_ENABLED` | 可选 | 覆盖 `api-auth.enabled`，默认 `false`（prod profile 自动 `true`） |
| `CORS_ALLOWED_ORIGINS` | 可选 | CORS 允许的来源域名，多个用逗号分隔（默认 `*`，prod 默认 `https://api.suikouji.com`） |
| `RATE_LIMIT_TRUSTED_PROXIES` | 生产建议 | 反向代理 IP（如 Nginx），用于正确解析客户端真实 IP（prod 默认 `127.0.0.1`） |
| `SPRING_PROFILES_ACTIVE` | 建议 | `dev` / `prod` |
| `JAVA_OPTS` | 可选 | 追加 JVM 参数（Dockerfile 默认: G1GC + MaxRAMPercentage=75% + StringDeduplication） |
| `SERVER_PORT` | 可选 | 覆盖默认端口 8080 |
| `LOG_DIR` | 可选 | 日志文件输出目录（默认 `logs`，仅 prod profile 生效） |

### Server 配置文件

| 文件 | 用途 |
|------|------|
| `application.yml` | 基础配置（所有环境共享） |
| `application-dev.yml` | 开发环境（TRACE 日志、暴露健康详情） |
| `application-prod.yml` | 生产环境（API 认证启用、精简日志、严格限流） |
| `logback-spring.xml` | 日志格式与级别（含 MDC requestId 关联 ID） |

### Client 配置文件

| 文件 | 配置项 | 说明 |
|------|--------|------|
| `lib/core/network/api_config.dart` | `_defaultBaseUrl` | 默认 Server 地址 |
| `android/app/build.gradle.kts` | `applicationId` | Android 包名 |
| `ios/Runner.xcodeproj` | Bundle Identifier | iOS 包标识 |

### Docker 文件

| 文件 | 用途 |
|------|------|
| `voice-note-server/Dockerfile` | Server 容器镜像 |
| `deploy/docker-compose.yml` | 编排部署（默认 prod，通过 `.env` 切换） |
| `deploy/.env.example` | 环境变量模板（可提交 Git） |
| `deploy/.env` | 实际环境变量（**不提交 Git**） |

### API 合约

| 文件 | 用途 |
|------|------|
| `api-contracts/voice-note-api.yaml` | OpenAPI 3.0 规范，Client-Server 接口定义 |

---

## 8. 客户端语音错误码（ASR Token）

语音记账页在调用 `POST /api/v1/asr/token` 失败时，聊天窗口会显示友好文案并附带错误码，便于工程师根据用户反馈或截图快速定位问题。

| 错误码 | 接口/异常类型 | 用户可见文案 | 排查建议 |
|--------|----------------|--------------|----------|
| E-ASR-001 | `POST /api/v1/asr/token` 超时（客户端 TimeoutException） | 获取语音服务超时，请检查网络后重试 [E-ASR-001] | 检查网络延迟、Server 与 DashScope 可用性及客户端/服务端超时配置 |
| E-ASR-002 | 网络不可达（NetworkUnavailableException / connectionError） | 无法连接网络，请检查网络后重试 [E-ASR-002] | 检查客户端网络、DNS、防火墙及 Server 地址是否可达 |
| E-ASR-003 | `POST /api/v1/asr/token` 返回 429（RateLimitException） | 请求过于频繁，请稍后再试 [E-ASR-003] | 检查 Server 限流配置（`rate-limit.asr`）与同一 IP 请求频率 |
| E-ASR-004 | Token 响应无效（空 token/wsUrl） | 语音服务暂时不可用，请稍后重试 [E-ASR-004] | 检查 Server 与 DashScope Token API 响应及服务端日志 |
| E-ASR-005 | 其它 AsrToken 失败（如 4xx/5xx、未知异常） | 启动语音识别失败，请稍后重试 [E-ASR-005] | 查看客户端 debug 日志及 Server 对应请求日志 |

---

## 9. 客户端语音错误码（LLM 解析/纠错）

语音记账页在调用 `POST /api/v1/llm/parse-transaction`（语义解析）或 `POST /api/v1/llm/correct-transaction`（纠错）失败时，聊天窗口会显示友好文案并附带错误码，便于工程师根据用户反馈或截图快速定位问题。两接口共用同一套错误码 E-LLM-001～005。

| 错误码 | 接口 | 异常类型 | 用户可见文案 | 排查建议 |
|--------|------|----------|--------------|----------|
| E-LLM-001 | parse-transaction / correct-transaction | 超时（TimeoutException） | 语义解析请求超时，请检查网络后重试 [E-LLM-001] | 检查网络延迟与 Server/LLM 超时配置 |
| E-LLM-002 | parse-transaction / correct-transaction | 网络不可达（NetworkUnavailableException） | 无法连接网络，请检查网络后重试 [E-LLM-002] | 检查客户端网络、DNS、防火墙及 Server 地址是否可达 |
| E-LLM-003 | parse-transaction / correct-transaction | 返回 429（RateLimitException） | 请求过于频繁，请稍后再试 [E-LLM-003] | 检查 Server 限流配置（`rate-limit.llm`）与同一 IP 请求频率 |
| E-LLM-004 | parse-transaction / correct-transaction | 返回 422（LLM 解析失败） | 语义解析暂时不可用，请稍后重试 [E-LLM-004] | 查看服务端及 LLM 上游日志 |
| E-LLM-005 | parse-transaction / correct-transaction | 其它（400/5xx、Validation/Server/Upstream） | 语义解析失败，请稍后重试 [E-LLM-005] | 查看客户端 debug 日志及 Server 对应请求日志 |
