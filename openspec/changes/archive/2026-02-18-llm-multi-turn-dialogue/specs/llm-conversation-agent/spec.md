## ADDED Requirements

### Requirement: 多轮对话端点
系统 SHALL 提供 REST 端点 `POST /api/v1/llm/conversation`，接收对话历史（messages 数组）、当前交易上下文和用户上下文，调用 LLM 返回结构化动作响应。请求体 SHALL 包含 `messages`（必填，`List<{role, content}>`）、`currentTransaction`（可选，当前交易字段）和 `context`（可选，包含 recentCategories、customCategories）。响应 SHALL 包含 `action`（枚举：correct / parse / clarify / query）、`transaction`（当 action 为 correct 或 parse 时的完整交易数据）和 `message`（当 action 为 clarify 时的追问文本）。

#### Scenario: 纠正交易类型
- **WHEN** 客户端发送 `{messages: [{role:"user", content:"红包收了60元"}, {role:"assistant", content:"{action:parse,...}"}, {role:"user", content:"不对，是收入"}], currentTransaction: {amount:60, type:"EXPENSE", category:"红包"}}`
- **THEN** 系统 SHALL 返回 `{action: "correct", transaction: {amount:60, type:"INCOME", category:"红包", confidence: ≥0.9}, message: null}`

#### Scenario: 纠正分类
- **WHEN** 用户对话历史中最新消息为"改成交通"，当前交易 category 为"餐饮"
- **THEN** 系统 SHALL 返回 `{action: "correct", transaction: {..., category:"交通"}, message: null}`

#### Scenario: 意图不明需追问
- **WHEN** 用户最新消息为"那个不对"，语义模糊无法确定要修改哪个字段
- **THEN** 系统 SHALL 返回 `{action: "clarify", transaction: null, message: "请问您想修改哪个部分？金额、分类还是类型？"}`

#### Scenario: 用户输入新交易
- **WHEN** 用户在确认阶段说了一笔新交易（如"午饭花了35"），与当前交易无关
- **THEN** 系统 SHALL 返回 `{action: "parse", transaction: {amount:35, category:"餐饮", type:"EXPENSE"}, message: null}`

#### Scenario: 用户查询统计
- **WHEN** 用户在确认阶段说"这个月花了多少"
- **THEN** 系统 SHALL 返回 `{action: "query", transaction: null, message: "这个月花了多少"}`

#### Scenario: 请求体校验失败
- **WHEN** 客户端发送空 messages 数组 `{messages: []}`
- **THEN** 系统 SHALL 返回 HTTP 400

### Requirement: 多轮 LLM Provider 接口
系统 SHALL 在 LlmProvider 接口提供多轮对话方法 `chatCompletion(systemPrompt, messages)`，接收 system prompt 和 `List<ChatMessage>` 消息列表。`ChatMessage` SHALL 包含 `role`（system / user / assistant）和 `content` 字段。DashScopeLlmProvider SHALL 实现该方法，将 messages 列表直接映射为 DashScope OpenAI-compatible API 的 messages 数组。现有单轮 `chatCompletion(systemPrompt, userMessage)` 方法 SHALL 保持不变。

#### Scenario: 多轮调用成功
- **WHEN** ConversationService 使用包含 3 条消息的 messages 列表调用 chatCompletion
- **THEN** Provider SHALL 构造包含 1 条 system + 3 条对话消息的请求发送给 DashScope

#### Scenario: 多轮调用降级
- **WHEN** 主模型多轮调用失败
- **THEN** 系统 SHALL 自动降级到备选模型，使用相同的 messages 列表重试

### Requirement: 对话 Prompt 模板
系统 SHALL 通过 PromptManager 加载 `prompts/conversation-agent.txt` 模板。模板 SHALL 定义 LLM 角色为记账助手、输入格式（当前交易 JSON + 对话历史）、输出格式（严格 JSON 含 action 枚举）。模板 SHALL 定义 action 路由规则：用户纠正字段返回 `correct`（含完整更新后交易）、用户说新交易返回 `parse`（解析新交易）、意图不明返回 `clarify`（含追问 message）、用户查询统计返回 `query`。

#### Scenario: 模板加载
- **WHEN** ConversationService 首次处理对话请求
- **THEN** 系统 SHALL 从 `prompts/conversation-agent.txt` 加载并缓存模板

#### Scenario: 当前交易注入 Prompt
- **WHEN** 请求包含 currentTransaction 字段
- **THEN** system prompt 末尾 SHALL 附加当前交易的 JSON 表示

### Requirement: 对话响应解析与容错
ConversationService SHALL 解析 LLM 返回的 JSON 响应。若 JSON 解析失败或 action 不在枚举范围内，系统 SHALL 返回 `{action: "clarify", message: "抱歉没有理解，请再说一次"}` 作为兜底，SHALL NOT 抛出异常或返回 5xx 错误。

#### Scenario: LLM 返回非 JSON
- **WHEN** LLM 返回纯文本而非 JSON 格式
- **THEN** 系统 SHALL 返回 clarify 兜底响应

#### Scenario: LLM 返回未知 action
- **WHEN** LLM 返回 `{action: "unknown_action"}`
- **THEN** 系统 SHALL 返回 clarify 兜底响应

### Requirement: 客户端对话历史管理
客户端 SHALL 提供 ConversationHistory 组件管理对话轮次。ConversationHistory SHALL 维护 `List<ConversationMessage>`，提供 `addUserMessage(text)`、`addAssistantResponse(action, transaction, message)` 和 `clear()` 方法。消息上限 SHALL 为 10 条，超限后 SHALL 采用 FIFO 淘汰策略——保留第一条用户消息 + 最近 9 条消息。`clear()` SHALL 在交易确认/取消/退出时调用。`toRequestMessages()` SHALL 序列化为 API 请求所需的 messages 格式。

#### Scenario: 正常添加消息
- **WHEN** 用户说了一句话且 LLM 返回响应
- **THEN** ConversationHistory SHALL 依次添加 user message 和 assistant message，长度增加 2

#### Scenario: 超限淘汰
- **WHEN** 对话历史已有 10 条消息，用户再说一句话
- **THEN** ConversationHistory SHALL 淘汰第 2 条消息（保留第 1 条），插入新消息，总数保持 10

#### Scenario: 交易确认后清空
- **WHEN** 用户确认当前交易
- **THEN** ConversationHistory SHALL 清空所有消息

### Requirement: 客户端对话 API 调用
客户端 SHALL 提供 ConversationRepository 组件封装 `POST /api/v1/llm/conversation` API 调用。ConversationRepository SHALL 接收 ConversationHistory 的序列化 messages、当前交易上下文和用户上下文，返回 ConversationResponse（含 action、transaction、message）。API 调用失败时 SHALL 抛出异常，由上层处理降级。

#### Scenario: API 调用成功
- **WHEN** ConversationRepository 发送对话请求且服务端正常响应
- **THEN** SHALL 返回解析后的 ConversationResponse 对象

#### Scenario: API 调用网络错误
- **WHEN** 网络不可达导致 API 调用失败
- **THEN** ConversationRepository SHALL 抛出异常
