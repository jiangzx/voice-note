## ADDED Requirements

### Requirement: ASR 临时 Token 生成
系统 SHALL 提供 REST 端点 `POST /api/v1/asr/token`，调用 DashScope Token API 生成临时 API Key，返回给客户端用于直连 ASR WebSocket。响应 SHALL 包含：临时 Token、过期时间戳（Unix 秒）、ASR 模型标识、WebSocket URL。服务端 SHALL 使用环境变量中的永久 API Key 调用 DashScope，永久 Key SHALL NOT 出现在响应中。

#### Scenario: 成功生成临时 Token
- **WHEN** 客户端发送 `POST /api/v1/asr/token`
- **THEN** 系统 SHALL 调用 DashScope `POST /api/v1/tokens?expire_in_seconds={ttl}` 并返回 JSON `{token, expiresAt, model, wsUrl}`，HTTP 200

#### Scenario: Token TTL 可配置
- **WHEN** 配置 `dashscope.asr.token-ttl-seconds=600`
- **THEN** 生成的临时 Token 有效期 SHALL 为 600 秒

#### Scenario: DashScope Token API 不可用
- **WHEN** DashScope Token API 返回非 200 状态码
- **THEN** 系统 SHALL 返回 HTTP 502，响应体 SHALL 包含 `{error: "upstream_error", message, timestamp}`

### Requirement: ASR 端点限流
系统 SHALL 对 `/api/v1/asr/**` 路径实施 IP 维度令牌桶限流。默认 SHALL 为每 IP 每分钟 30 次请求。限流参数 SHALL 通过 `application.yml` 配置。

#### Scenario: 正常请求通过
- **WHEN** 同一 IP 在 1 分钟内第 1-30 次请求 ASR Token
- **THEN** 系统 SHALL 正常处理并返回 Token

#### Scenario: 超限请求拒绝
- **WHEN** 同一 IP 在 1 分钟内第 31 次请求 ASR Token
- **THEN** 系统 SHALL 返回 HTTP 429，响应体 SHALL 包含 `{error: "rate_limit_exceeded", message}`

#### Scenario: 不同 IP 独立计数
- **WHEN** IP-A 已用 30 次配额，IP-B 发送第 1 次请求
- **THEN** IP-B 的请求 SHALL 正常通过
