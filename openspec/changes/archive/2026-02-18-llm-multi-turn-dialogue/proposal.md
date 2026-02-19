## Why

当前确认阶段使用本地关键词匹配（`VoiceCorrectionHandler`），无法理解自然语言纠正（如"修改为收入"、"不对，应该是交通"），导致纠正指令被错误地当做新交易处理，上下文丢失，用户体验断裂。同时，用户未来需要通过语音查询统计数据（"这个月花了多少"），而现有的单轮 LLM 架构无法支持对话式交互。

## What Changes

- **新增多轮对话 API**：服务端新增 `POST /api/v1/llm/conversation` 端点，接收对话历史（messages）+ 当前交易上下文，返回结构化动作（解析/纠正/确认/查询/退出）
- **新增多轮对话 Prompt 模板**：创建 `conversation-agent.txt`，定义 LLM 作为记账助手的角色、可执行动作、输出格式
- **客户端混合路由改造**：确认阶段采用"快速路径 + LLM 慢速路径"模式——确认/取消/退出仍走本地关键词匹配（零延迟），纠正和模糊意图发送给 LLM 并附带对话历史
- **客户端对话上下文管理**：`VoiceOrchestrator` 维护当前会话的对话轮次列表（user/assistant messages），每轮 LLM 调用携带完整历史
- **查询意图支持**：LLM 返回 `query` action 时，客户端路由到统计查询流程（本期仅定义接口，查询执行留作后续迭代）

## Capabilities

### New Capabilities
- `llm-conversation-agent`: 多轮对话代理——服务端 API、Prompt 设计、action 路由、对话历史管理

### Modified Capabilities
- `ai-gateway-llm`: 新增 `/api/v1/llm/conversation` 端点，在现有 LLM 代理基础上增加多轮对话能力
- `voice-orchestration`: 确认阶段从纯本地关键词路由改为混合路由（本地快速路径 + LLM 慢速路径），增加对话上下文管理

## Impact

- **服务端**：`voice-note-server` 新增 Controller + Service + Prompt 模板，复用现有 `DashScopeLlmProvider` 和模型降级机制
- **客户端**：`voice-note-client` 修改 `VoiceOrchestrator`（对话上下文）、`VoiceCorrectionHandler`（保留快速路径）、`NlpOrchestrator`（新增多轮调用路径）、`LlmRepository`（新增 conversation API）
- **API 契约**：`api-contracts/voice-note-api.yaml` 新增 conversation 端点定义
- **成本影响**：确认阶段的纠正操作从零成本（本地）变为 LLM API 调用（~100-300ms、~0.001 元/次），明确的确认/取消/退出仍走本地零成本路径
