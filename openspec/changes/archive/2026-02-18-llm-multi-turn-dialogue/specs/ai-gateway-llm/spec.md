## ADDED Requirements

### Requirement: 多轮对话端点路由
系统 SHALL 在现有 LlmController 中新增 `POST /api/v1/llm/conversation` 端点映射。该端点 SHALL 委托给 ConversationService 处理。该端点 SHALL 复用现有 `/api/v1/llm/**` 路径的限流规则（每 IP 每分钟 60 次）。

#### Scenario: 对话端点可访问
- **WHEN** 客户端 POST `/api/v1/llm/conversation` 并携带有效请求体
- **THEN** 系统 SHALL 返回 HTTP 200 及 ConversationResponse JSON

#### Scenario: 对话端点受限流保护
- **WHEN** 同一 IP 在 1 分钟内累计请求 `/api/v1/llm/parse-transaction` 和 `/api/v1/llm/conversation` 超过 60 次
- **THEN** 系统 SHALL 返回 HTTP 429

## MODIFIED Requirements

### Requirement: Prompt 模板管理
系统 SHALL 从类路径 `prompts/` 目录加载 Prompt 模板文件。模板 SHALL 以文件名标识（如 `transaction-parse.txt`、`conversation-agent.txt`）。模板 SHALL 在首次使用时加载并缓存。系统 SHALL 在 System Prompt 中注入用户上下文（自定义分类、最近使用分类、账户列表）。系统启动时 SHALL 校验 `transaction-parse` 和 `conversation-agent` 两个必需模板均可加载。

#### Scenario: 模板加载成功
- **WHEN** 系统首次处理交易解析请求
- **THEN** 系统 SHALL 从 `prompts/transaction-parse.txt` 加载 Prompt 模板

#### Scenario: 模板缓存复用
- **WHEN** 系统第 2 次处理交易解析请求
- **THEN** 系统 SHALL 复用缓存的模板，不重新读取文件

#### Scenario: 上下文注入
- **WHEN** 请求包含 `context.customCategories=["学习资料", "宠物用品"]`
- **THEN** System Prompt SHALL 包含这些自定义分类信息

#### Scenario: 对话模板加载
- **WHEN** ConversationService 首次处理对话请求
- **THEN** 系统 SHALL 从 `prompts/conversation-agent.txt` 加载并缓存模板

#### Scenario: 启动时校验必需模板
- **WHEN** 应用启动
- **THEN** 系统 SHALL 校验 `transaction-parse` 和 `conversation-agent` 模板均可加载，任一缺失 SHALL 启动失败
