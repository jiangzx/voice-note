## ADDED Requirements

### Requirement: 交易文本解析
系统 SHALL 提供 REST 端点 `POST /api/v1/llm/parse-transaction`，接收自然语言文本及可选上下文，调用 LLM 返回结构化交易数据。请求体 SHALL 包含 `text`（必填）和可选 `context`（包含 recentCategories、customCategories、accounts）。响应 SHALL 包含：amount、currency、date、category、description、type、account、confidence、model。无法确定的字段 SHALL 返回 null。

#### Scenario: 完整信息解析
- **WHEN** 客户端发送 `{text: "今天午饭花了35"}`
- **THEN** 系统 SHALL 返回 `{amount: 35, date: "今天对应日期", category: "餐饮", type: "EXPENSE", confidence: ≥0.8, model: "使用的模型名"}`

#### Scenario: 部分信息解析
- **WHEN** 客户端发送 `{text: "打车28块"}`
- **THEN** 系统 SHALL 返回 `{amount: 28, category: "交通", type: "EXPENSE", date: null, confidence: <1.0}`

#### Scenario: 上下文增强解析
- **WHEN** 客户端发送 `{text: "买了本书", context: {customCategories: ["学习资料"]}}`
- **THEN** 系统 SHALL 优先使用用户自定义分类"学习资料"而非默认分类

#### Scenario: 请求体校验失败
- **WHEN** 客户端发送 `{text: ""}`（空文本）
- **THEN** 系统 SHALL 返回 HTTP 400，响应体 SHALL 包含 `{error: "validation_failed"}`

### Requirement: LLM 模型降级路由
系统 SHALL 优先使用主模型（primary-model）解析。若主模型调用失败（超时、错误、无法提取 JSON），系统 SHALL 自动降级到备选模型（fallback-model）。主模型和备选模型 SHALL 通过 `application.yml` 配置。

#### Scenario: 主模型成功
- **WHEN** 主模型（qwen-turbo）成功解析用户输入
- **THEN** 响应 `model` 字段 SHALL 为 "qwen-turbo"

#### Scenario: 主模型失败自动降级
- **WHEN** 主模型调用超时或返回错误
- **THEN** 系统 SHALL 自动调用备选模型（qwen-plus）并返回其结果，响应 `model` 字段 SHALL 为 "qwen-plus"

#### Scenario: 双模型均失败
- **WHEN** 主模型和备选模型均调用失败
- **THEN** 系统 SHALL 返回 HTTP 422，响应体 SHALL 包含 `{error: "llm_parse_failed"}`

### Requirement: Prompt 模板管理
系统 SHALL 从类路径 `prompts/` 目录加载 Prompt 模板文件。模板 SHALL 以文件名标识（如 `transaction-parse.txt`）。模板 SHALL 在首次使用时加载并缓存。系统 SHALL 在 System Prompt 中注入用户上下文（自定义分类、最近使用分类、账户列表）。

#### Scenario: 模板加载成功
- **WHEN** 系统首次处理交易解析请求
- **THEN** 系统 SHALL 从 `prompts/transaction-parse.txt` 加载 Prompt 模板

#### Scenario: 模板缓存复用
- **WHEN** 系统第 2 次处理交易解析请求
- **THEN** 系统 SHALL 复用缓存的模板，不重新读取文件

#### Scenario: 上下文注入
- **WHEN** 请求包含 `context.customCategories=["学习资料", "宠物用品"]`
- **THEN** System Prompt SHALL 包含这些自定义分类信息

### Requirement: LLM 端点限流
系统 SHALL 对 `/api/v1/llm/**` 路径实施 IP 维度令牌桶限流。默认 SHALL 为每 IP 每分钟 60 次请求。

#### Scenario: LLM 限流触发
- **WHEN** 同一 IP 在 1 分钟内第 61 次请求 LLM 解析
- **THEN** 系统 SHALL 返回 HTTP 429
