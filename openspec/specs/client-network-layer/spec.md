## Purpose

定义客户端 HTTP 网络层的系统行为，包括统一 HTTP 客户端封装、错误处理、Server 连接配置、请求重试和网络状态检测。

## Requirements

### Requirement: HTTP 客户端封装
系统 SHALL 提供统一的 HTTP 客户端（基于 dio），用于与 voice-note-server 通信。客户端 SHALL 支持：JSON 序列化/反序列化、请求超时配置、请求/响应日志（仅 debug 模式）。Base URL SHALL 通过配置管理，支持开发/生产环境切换。

#### Scenario: 成功请求
- **WHEN** 客户端调用 Server API 且 Server 返回 200
- **THEN** 系统 SHALL 将 JSON 响应反序列化为对应 Dart 对象并返回

#### Scenario: 请求超时
- **WHEN** Server 在配置的超时时间内未响应
- **THEN** 系统 SHALL 抛出超时异常，调用方 SHALL 可捕获并处理

#### Scenario: Base URL 配置
- **WHEN** 用户通过设置页修改 Server 地址
- **THEN** HTTP 客户端 SHALL 使用用户配置的 Base URL（持久化到 SharedPreferences）

### Requirement: 错误处理
系统 SHALL 统一处理 Server 返回的错误响应。HTTP 4xx/5xx 响应 SHALL 解析为标准错误对象（包含 error code 和 message）。网络不可达 SHALL 触发特定异常类型，调用方可据此降级到离线模式。

#### Scenario: Server 返回 422
- **WHEN** Server 返回 `{error: "llm_parse_failed", message: "..."}`
- **THEN** 系统 SHALL 解析为 `LlmParseError` 异常，调用方可展示友好提示

#### Scenario: Server 返回 429
- **WHEN** Server 返回 HTTP 429（限流）
- **THEN** 系统 SHALL 解析为 `RateLimitError` 异常，调用方 SHALL 展示"请稍后重试"

#### Scenario: 网络不可达
- **WHEN** 设备无网络连接
- **THEN** 系统 SHALL 抛出 `NetworkUnavailableError`，语音模块 SHALL 提示切换到手动输入

### Requirement: Server 连接配置
系统 SHALL 提供 Server 连接配置管理，包含 Base URL、超时时间和 API Key。配置 SHALL 支持通过设置页修改（高级设置）。默认配置 SHALL 指向生产环境。

#### Scenario: 默认开发配置
- **WHEN** App 首次启动
- **THEN** 系统 SHALL 使用预设的默认 Base URL（开发阶段为 `http://localhost:8080`，正式发布前更新为生产地址），API Key 默认为空（不携带认证头）

#### Scenario: 自定义 Server 地址
- **WHEN** 用户在高级设置中修改 Server 地址
- **THEN** 后续所有 API 请求 SHALL 使用新地址

### Requirement: API Key 请求头
系统 SHALL 支持通过 `X-API-Key` HTTP header 向 Server 发送认证凭据。API Key SHALL 持久化到 SharedPreferences（键名 `api_auth_key`）。构造 ApiClient 时 SHALL 从 ApiConfig 读取 Key 并注入到 BaseOptions headers。SHALL 支持运行时动态更新 Key（无需重建 ApiClient）。Key 为空时 SHALL NOT 携带 `X-API-Key` header。

#### Scenario: 带 Key 请求
- **WHEN** ApiConfig.apiKey 非空
- **THEN** 所有 API 请求 SHALL 在 header 中携带 `X-API-Key: <key>`

#### Scenario: 无 Key 请求
- **WHEN** ApiConfig.apiKey 为空
- **THEN** API 请求 SHALL NOT 包含 `X-API-Key` header

#### Scenario: 运行时更新 Key
- **WHEN** 用户在设置页修改 API Key
- **THEN** ApiClient SHALL 通过 `updateApiKey()` 立即更新 header，无需重建实例

### Requirement: HTTP 请求重试
系统 SHALL 对瞬态网络错误自动重试。重试 SHALL 使用指数退避策略（1s → 2s → 4s），最大重试次数 SHALL 为 3 次。SHALL 仅重试连接超时、请求超时和 5xx 服务端错误。SHALL NOT 重试 4xx 客户端错误。

#### Scenario: 5xx 错误自动重试
- **WHEN** Server 返回 HTTP 502 且重试次数 < 3
- **THEN** 系统 SHALL 等待退避时间后自动重发请求

#### Scenario: 4xx 错误不重试
- **WHEN** Server 返回 HTTP 400 或 422
- **THEN** 系统 SHALL 立即将错误返回给调用方，SHALL NOT 重试

#### Scenario: 重试耗尽
- **WHEN** 3 次重试后仍然失败
- **THEN** 系统 SHALL 将最后一次错误返回给调用方

### Requirement: 网络状态检测
系统 SHALL 实时监控设备网络连接状态。状态变化 SHALL 通过 Stream 向订阅方广播。离线状态 SHALL 影响 NLP 策略（仅使用本地引擎，跳过 LLM 兜底）。UI SHALL 在离线时展示提示横幅。

#### Scenario: 网络断开
- **WHEN** 设备从在线切换为离线
- **THEN** NetworkStatusService.isOnline SHALL 变为 false，onStatusChange Stream SHALL 发出 false 事件

#### Scenario: 离线时 NLP 策略降级
- **WHEN** 设备处于离线状态且用户进行语音记账
- **THEN** NlpOrchestrator SHALL 仅使用本地引擎解析，SHALL NOT 尝试调用 Server LLM

#### Scenario: 网络恢复
- **WHEN** 设备从离线恢复为在线
- **THEN** 系统 SHALL 恢复完整 NLP 策略（本地 + LLM 兜底），离线提示 SHALL 消失
