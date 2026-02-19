## Purpose

定义系统部署与运行环境配置的行为规格，包括多环境 profile 管理、敏感信息处理、容器化部署和安全要求。

## Requirements

### Requirement: Server 环境配置
系统 SHALL 通过 Spring profiles 管理多环境配置。SHALL 支持 dev（开发）和 prod（生产）两个 profile。所有敏感信息（API Key）SHALL 通过环境变量注入，不得硬编码。

#### Scenario: 开发环境启动
- **WHEN** 以 dev profile 启动 Server
- **THEN** 系统 SHALL 启用 TRACE 级日志、完整健康检查详情、API Key 认证默认关闭

#### Scenario: 生产环境启动
- **WHEN** 以 prod profile 启动 Server
- **THEN** 系统 SHALL 启用 INFO 级日志、隐藏健康检查详情、缩短 ASR Token TTL 至 120s、启用 API Key 认证

#### Scenario: DASHSCOPE_API_KEY 缺失
- **WHEN** 未设置 DASHSCOPE_API_KEY 环境变量
- **THEN** Server SHALL 启动失败并输出明确错误提示

### Requirement: API Key 接口认证
Server SHALL 支持通过 `X-API-Key` HTTP header 对 `/api/**` 端点进行认证。认证 SHALL 通过 `api-auth.enabled` 配置开关控制（默认关闭），密钥 SHALL 通过 `API_AUTH_KEY` 环境变量注入。认证拦截器 SHALL 在限流拦截器之前执行。

#### Scenario: 认证关闭
- **WHEN** `api-auth.enabled=false`
- **THEN** 系统 SHALL 放行所有请求，不检查 `X-API-Key` header

#### Scenario: 认证开启且 Key 有效
- **WHEN** `api-auth.enabled=true` 且请求携带正确的 `X-API-Key` header
- **THEN** 系统 SHALL 放行请求

#### Scenario: 认证开启且 Key 无效或缺失
- **WHEN** `api-auth.enabled=true` 且请求未携带或携带错误的 `X-API-Key` header
- **THEN** 系统 SHALL 返回 HTTP 401 和 JSON 错误体 `{"error":"unauthorized","message":"Invalid or missing API key"}`

### Requirement: CORS 跨域访问控制
Server SHALL 对 `/api/**` 端点配置 CORS 策略。允许的来源域名 SHALL 通过 `cors.allowed-origins` 配置（支持逗号分隔多域名）。开发环境默认 SHALL 为 `*`（允许所有来源）。生产环境 SHALL 通过 `CORS_ALLOWED_ORIGINS` 环境变量限制为实际域名。允许的 HTTP 方法 SHALL 限定为 `GET`、`POST`、`OPTIONS`。预检请求缓存时间 SHALL 为 3600 秒。

#### Scenario: 开发环境 CORS
- **WHEN** 以 dev profile 启动 Server 且未设置 `CORS_ALLOWED_ORIGINS`
- **THEN** 系统 SHALL 允许所有来源的跨域请求（`*`）

#### Scenario: 生产环境 CORS 限制
- **WHEN** 以 prod profile 启动 Server 且设置 `CORS_ALLOWED_ORIGINS=https://app.suikouji.com`
- **THEN** 系统 SHALL 仅允许来自 `https://app.suikouji.com` 的跨域请求

#### Scenario: 多域名 CORS
- **WHEN** 设置 `CORS_ALLOWED_ORIGINS=https://app.suikouji.com,https://admin.suikouji.com`
- **THEN** 系统 SHALL 允许来自这两个域名的跨域请求

### Requirement: Rate Limit 真实 IP 解析
当 Server 部署在反向代理（Nginx/ALB）后面时，限流器 SHALL 通过 `rate-limit.trusted-proxies` 配置可信代理 IP 列表。仅当直连 IP 属于可信代理时，系统 SHALL 从 `X-Forwarded-For` 或 `X-Real-IP` header 解析客户端真实 IP。未配置可信代理时，系统 SHALL 使用直连 IP 进行限流。

#### Scenario: 无反向代理直连
- **WHEN** 客户端直接连接 Server（无可信代理配置）
- **THEN** 系统 SHALL 使用 `request.remoteAddr` 作为限流维度的客户端 IP

#### Scenario: 通过可信代理连接
- **WHEN** 请求来自已配置的可信代理 IP 且携带 `X-Forwarded-For` header
- **THEN** 系统 SHALL 取 `X-Forwarded-For` 中最后一个（rightmost）IP 作为客户端真实 IP，以抵抗 XFF 伪造攻击

#### Scenario: 通过非可信代理连接
- **WHEN** 请求来自未配置在 `trusted-proxies` 中的 IP 且携带 `X-Forwarded-For` header
- **THEN** 系统 SHALL 忽略 `X-Forwarded-For`，使用直连 IP 作为限流维度（防止 IP 伪造）

### Requirement: Client Server 地址配置
Client SHALL 支持运行时修改 Server 基础地址。默认地址 SHALL 通过 `_defaultBaseUrl` 常量定义。用户修改的地址 SHALL 持久化到 SharedPreferences。发布生产版本前 SHALL 将默认地址更新为生产域名。

#### Scenario: 默认开发地址
- **WHEN** App 首次安装且未修改 Server 地址
- **THEN** Client SHALL 使用 `http://localhost:8080` 作为默认地址（开发版本）

#### Scenario: 生产默认地址
- **WHEN** 发布生产版本
- **THEN** `_defaultBaseUrl` SHALL 更新为 `https://api.suikouji.com`（或实际生产域名）

### Requirement: Docker 容器化部署
Server SHALL 提供 Dockerfile 支持容器化部署。Docker 镜像 SHALL 基于 JRE Alpine（最小化镜像体积）。SHALL 支持通过环境变量传入所有可配置参数。SHALL 内置健康检查端点。

#### Scenario: Docker 构建与运行
- **WHEN** 执行 `docker build` + `docker run`
- **THEN** Server SHALL 正常启动并通过 `/actuator/health` 响应

#### Scenario: Docker Compose 部署
- **WHEN** 执行 `docker compose up`
- **THEN** Server SHALL 通过 compose 配置的环境变量和 profile 正确初始化

### Requirement: iOS 平台权限
iOS 构建 SHALL 在 Info.plist 中声明 `NSMicrophoneUsageDescription`，描述麦克风用途（语音记账）。缺失该声明将导致语音功能不可用。

#### Scenario: 麦克风权限声明
- **WHEN** 构建 iOS 应用
- **THEN** Info.plist SHALL 包含 `NSMicrophoneUsageDescription` 键值对

### Requirement: 结构化日志与请求关联 ID
Server SHALL 使用 `logback-spring.xml` 管理日志格式和级别。每条日志 SHALL 包含 MDC `requestId` 字段用于请求链路追踪。Server SHALL 通过 `CorrelationIdFilter`（`OncePerRequestFilter`）在请求入口生成或复用 `X-Request-ID` header，写入 MDC 并回传到响应 header。日志 SHALL 不记录上游 API 响应体内容以防止敏感数据泄露。

#### Scenario: 自动生成关联 ID
- **WHEN** 客户端请求未携带 `X-Request-ID` header
- **THEN** Server SHALL 自动生成 8 位短 UUID 作为 requestId，写入 MDC 和响应 `X-Request-ID` header

#### Scenario: 复用客户端关联 ID
- **WHEN** 客户端请求携带 `X-Request-ID` header
- **THEN** Server SHALL 复用该值作为 requestId

#### Scenario: MDC 清理
- **WHEN** 请求处理完成（包括异常情况）
- **THEN** Server SHALL 在 `finally` 块中清理 MDC，防止线程复用导致关联 ID 泄露

#### Scenario: 日志级别管理
- **WHEN** 以 prod profile 运行
- **THEN** `com.suikouji` 日志级别 SHALL 为 INFO（由 `logback-spring.xml` `<springProfile>` 控制）
- **WHEN** 以非 prod profile 运行
- **THEN** `com.suikouji` 日志级别 SHALL 为 DEBUG

### Requirement: 性能优化
Server SHALL 内置以下性能优化措施：WebClient 连接池管理（限制最大连接数、空闲回收、生命周期控制）、DashScope API 5xx 自动重试（指数退避）、ASR Token 内存缓存。Docker 部署 SHALL 包含 JVM 调优参数（G1GC、MaxRAMPercentage）。Client 数据库 SHALL 对高频查询字段创建索引，统计聚合查询 SHALL 使用 SQL SUM/GROUP BY 而非内存累加。

#### Scenario: DashScope 5xx 重试
- **WHEN** DashScope API 返回 5xx 服务端错误
- **THEN** 系统 SHALL 使用指数退避策略自动重试（最多 2 次，基础延迟 500ms），仅对 5xx 错误触发
- **AND** 重试耗尽后 SHALL 进入 fallback 模型流程

#### Scenario: ASR Token 缓存
- **WHEN** 请求 ASR Token 且缓存中存在未过期的 Token
- **THEN** 系统 SHALL 直接返回缓存的 Token，不调用 DashScope API
- **AND** Token SHALL 在原始过期时间前 30 秒自动失效

#### Scenario: WebClient 连接池
- **WHEN** Server 初始化 DashScope WebClient
- **THEN** SHALL 配置独立连接池（最大连接数、空闲时间、最大生命周期、后台驱逐）

#### Scenario: 数据库索引
- **WHEN** Client 数据库迁移到 schema v3
- **THEN** SHALL 在 transactions 表创建索引：`idx_tx_date_type`、`idx_tx_category`、`idx_tx_account`、`idx_tx_is_draft`

### Requirement: 安全配置
生产部署 SHALL 满足以下安全要求：HTTPS 加密传输、API Key 环境变量注入、API 接口认证（`X-API-Key`）、CORS 来源限制、IP 限流保护（含可信代理真实 IP 解析）、ASR Token 短有效期（≤120s）。

#### Scenario: HTTPS 强制
- **WHEN** 部署到生产环境
- **THEN** 所有 Client-Server 通信 SHALL 通过 HTTPS；HTTP 请求 SHALL 被重定向到 HTTPS
