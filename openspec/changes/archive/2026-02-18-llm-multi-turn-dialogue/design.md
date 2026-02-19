## Context

当前系统在语音记账确认阶段仅依赖 `VoiceCorrectionHandler` 做本地关键词匹配。该方案对"确认/取消/退出/继续"等明确指令效果良好，但无法理解自然语言纠正（如"不对，应该是收入"、"改成交通类"），这类输入被错误归类为 `newInput` 并重新发起解析，导致对话上下文丢失、用户体验断裂。

服务端现有单轮 LLM 架构（`LlmService` + `LlmProvider.chatCompletion(systemPrompt, userMessage)`）只支持一问一答。本次变更需要在不破坏现有单轮接口的前提下，扩展出多轮对话能力。

### 现有架构约束
- **服务端**: Spring Boot + Kotlin 协程，分层架构（Controller → Service → Provider），支持 primary/fallback 模型降级
- **客户端**: Flutter + Riverpod，Feature-First 三层架构，`VoiceOrchestrator` 负责语音流程状态机
- **通信**: OpenAPI 3.0 契约驱动，客户端通过 `ApiClient` 调用 REST 端点

## Goals / Non-Goals

**Goals:**
- 确认阶段的纠正/模糊意图通过 LLM 多轮对话获得上下文感知的理解
- 保留本地快速路径（confirm/cancel/exit/continue），确保零延迟响应
- LLM 返回结构化 action（correct / parse / clarify / query），客户端按 action 路由处理
- 离线时自动降级到现有本地关键词匹配，不影响基本功能
- 为未来语音查询（query action）预留接口

**Non-Goals:**
- query action 的实际数据查询执行（仅定义接口和 action 类型）
- 流式响应（streaming）——当前延迟可接受，不做 SSE/WebSocket
- 服务端 session/对话状态管理——客户端全量发送历史，服务端保持无状态
- 修改现有单轮解析端点（`/api/v1/llm/parse-transaction`）

## Decisions

### D1: 服务端无状态 + 客户端维护对话历史

**选择**: 客户端内存维护 `List<ConversationMessage>`，每次 API 调用全量发送 messages，服务端不保存任何会话状态。

**替代方案**:
- 服务端 session 管理（Redis/内存 cache）：增加服务端复杂度和有状态部署约束，单用户场景无明显收益
- 数据库持久化对话：本场景对话生命周期短（单笔交易确认），无需持久化

**理由**: 服务端无状态最简单、最易部署和扩展。客户端已经持有完整上下文（当前交易 + 语音流），自然承担对话状态管理职责。对话历史在交易确认/取消/退出时清空，生命周期天然对齐。

### D2: 扩展 LlmProvider 接口而非新建 Provider

**选择**: 在 `LlmProvider` 接口新增 `chatCompletion(systemPrompt: String, messages: List<ChatMessage>)` 重载方法，`DashScopeLlmProvider` 实现新方法。

**替代方案**:
- 新建 `MultiTurnLlmProvider` 接口：接口分裂，需要额外的 Bean 配置，增加维护成本
- 在 `ConversationService` 内部直接构造 HTTP 请求：绕过 Provider 抽象，破坏模型降级机制

**理由**: `DashScopeLlmProvider` 内部已经使用 `messages` 数组构造请求，新增重载只是将内部能力外露。保持单一 Provider 抽象，模型降级（primary → fallback）机制可直接复用。

### D3: 独立 ConversationService 而非扩展 LlmService

**选择**: 新建 `ConversationService`，与现有 `LlmService` 平行，各自负责不同业务场景。

**替代方案**:
- 在 `LlmService` 中新增 `converse()` 方法：职责混合（单轮解析 vs 多轮对话），违反单一职责
- 统一为一个通用 LLM 编排 Service：过度抽象，两种场景的 prompt 构造、响应解析、错误处理差异较大

**理由**: 单轮解析（transaction-parse prompt + JSON 响应）和多轮对话（conversation-agent prompt + action 路由）在 prompt 模板、请求结构、响应格式上有本质区别。独立 Service 边界清晰，互不影响。两者共享 `LlmProvider` 层做实际 LLM 调用。

### D4: 客户端混合路由策略

**选择**: `VoiceCorrectionHandler.classify()` 保留作为第一道分类器。`confirm/cancel/exit/continue` 走本地零延迟路径；`correction/newInput` 在联网时走 LLM 对话端点，离线降级到本地 `applyCorrection()`。

**替代方案**:
- 所有确认阶段输入都发 LLM：明确指令（"确认"、"取消"）无需 LLM，增加不必要延迟和成本
- 客户端做更复杂的本地 NLU：投入产出比低，LLM 在意图理解上远优于规则匹配

**理由**: 明确指令占确认阶段 ~70% 的交互，本地处理保证零延迟体验。纠正/模糊意图需要上下文理解，是 LLM 的最佳应用场景。这种分层路由在延迟、成本和准确度之间取得最优平衡。

### D5: 对话历史上限与淘汰策略

**选择**: 最大 10 条消息（约 5 轮对话），超限后 FIFO 淘汰——保留第一条用户消息 + 最近 9 条。

**替代方案**:
- 无上限：token 爆炸风险，单次交易确认不应有超长对话
- 固定 6 条（3 轮）：对于连续纠正场景（先改金额、再改分类、再改类型）可能丢失早期上下文

**理由**: 10 条消息覆盖绝大多数实际纠正场景（通常 1-3 轮即完成），保留首条消息确保 LLM 始终知道原始输入。DashScope qwen-turbo 的 context window 充裕，10 条消息远未触及限制。

### D6: conversation-agent prompt 设计

**选择**: 新建 `prompts/conversation-agent.txt`，通过 `PromptManager` 加载。prompt 定义角色（记账助手）、输入格式（当前交易 JSON + 对话历史）、输出格式（严格 JSON，含 action 枚举）、action 路由规则。

**理由**: 复用现有 `PromptManager` 机制，保持 prompt 管理一致性。独立 prompt 文件便于迭代调优，不影响 transaction-parse prompt。

### D7: 新增 ConversationRepository 而非复用 LlmRepository

**选择**: 客户端新建 `ConversationRepository`，独立于现有 `LlmRepository`。

**替代方案**:
- 在 `LlmRepository` 新增 `converse()` 方法：请求/响应结构完全不同，混在一起增加理解成本

**理由**: 两个端点的 Request/Response DTO 结构不同（单文本 vs messages 数组 + 交易上下文；ParseResponse vs ConversationResponse with action）。独立 Repository 职责单一，DTO 定义清晰。

## Risks / Trade-offs

**[LLM 延迟]** → 纠正操作从零延迟（本地）变为 ~100-300ms（LLM API），用户可感知。
→ 缓解: 确认/取消/退出/继续仍走本地零延迟；仅纠正和模糊意图走 LLM。UI 可展示加载态。

**[LLM 成本增加]** → 每次纠正操作产生 ~0.001 元 API 成本。
→ 缓解: 明确指令走本地路径，仅约 30% 的确认阶段交互触发 LLM 调用。服务端复用现有 rate limiting 机制。

**[LLM 响应格式不稳定]** → LLM 可能返回非预期 JSON 结构或 action 值。
→ 缓解: 服务端 `ConversationService` 做 JSON 解析 + action 枚举校验；解析失败时返回 `clarify` action 让用户重试，不中断流程。客户端对未知 action 做 fallback 处理。

**[离线降级体验]** → 离线时纠正能力退化到关键词匹配，复杂纠正（如"改成上个月的"）无法处理。
→ 缓解: 这是现有行为的保持，不是本次变更引入的退化。联网后自动恢复 LLM 能力。

**[对话历史丢失]** → 客户端内存管理，App 被杀或页面切换时对话历史清空。
→ 可接受: 对话生命周期绑定单笔交易确认流程，流程中断时重新开始是合理的用户预期。

## 新增文件结构

### 服务端

```
voice-note-server/src/main/kotlin/com/suikouji/server/llm/
├── ConversationService.kt          # 多轮对话业务逻辑
├── dto/
│   ├── ConversationRequest.kt      # 对话请求 DTO
│   └── ConversationResponse.kt     # 对话响应 DTO（含 action 枚举）
└── provider/
    └── LlmProvider.kt              # 新增 chatCompletion 多轮重载

voice-note-server/src/main/resources/prompts/
└── conversation-agent.txt           # 多轮对话 prompt 模板
```

### 客户端

```
voice-note-client/lib/features/voice/
├── data/
│   └── conversation_repository.dart # 对话 API 调用 + DTOs
└── domain/
    └── conversation_history.dart    # 对话历史管理（内存，FIFO 淘汰）
```

### 修改文件

- `LlmProvider.kt` — 新增多轮 chatCompletion 重载
- `DashScopeLlmProvider.kt` — 实现多轮重载
- `LlmController.kt` — 新增 `/conversation` 端点
- `voice_orchestrator.dart` — `_handleConfirmingSpeech` 混合路由改造
- `api-contracts/voice-note-api.yaml` — 新增 conversation 端点定义
