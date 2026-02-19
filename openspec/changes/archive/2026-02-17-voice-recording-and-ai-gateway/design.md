## Context

随口记 App Phase 1 已完成纯客户端手动记账功能，采用 Flutter + drift (SQLite) + Riverpod 架构，数据完全存储在本地，local-first 设计。

Phase 2 需要引入语音记账能力，涉及两个外部云服务：
- **阿里云百炼 ASR**（qwen3-asr-flash-realtime）：实时流式语音识别，WebSocket 协议
- **阿里云百炼 LLM**（qwen-turbo / qwen-plus）：自然语言解析为结构化交易数据，OpenAI 兼容 HTTP API

当前约束：
- 客户端不可直接持有永久 API Key（逆向可提取）
- ASR 为实时流式传输，对延迟敏感（<100ms 额外延迟）
- LLM 调用需要 Prompt 管理和模型降级策略
- 无用户体系（Phase 5 才引入），限流只能基于 IP
- local-first 原则不可打破 —— Server 故障时手动记账必须完全可用

## Goals / Non-Goals

**Goals:**
- 安全接入 ASR 和 LLM 云服务，API Key 零泄露风险
- 客户端实现完整的语音记账交互链路（VAD → ASR → NLP → 确认）
- 支持离线场景下的基础 NLP 解析（本地规则引擎）
- LLM Provider 可通过配置切换，不改代码
- 统一限流和成本控制

**Non-Goals:**
- 不实现用户认证（Phase 5 范畴）
- 不实现云数据同步（Phase 5 范畴）
- 不实现 TTS 语音合成（使用客户端原生 TTS）
- 不实现离线唤醒词（v1.1+ 范畴，Porcupine）
- 不实现统计报表（Phase 3 范畴）

## Decisions

### D1: ASR 连接方式 — Token Broker 模式（不代理音频流）

**选择**：Server 仅发放 DashScope 临时 Token，客户端直连 ASR WebSocket。

**备选方案**：
| 方案 | 延迟 | 实现复杂度 | Server 负载 |
|------|------|-----------|------------|
| A. Token Broker（选定） | +0ms（直连） | 低 | 极低（仅 Token API） |
| B. Server WebSocket 代理 | +50-100ms | 高（双向代理） | 高（音频流量） |
| C. 客户端直连（无 Server） | +0ms | 极低 | 无 | 

**理由**：DashScope 支持临时 API Key（TTL 1-1800s），完美解决安全问题。方案 B 引入不可接受的实时延迟且大幅增加 Server 复杂度。方案 C 存在 API Key 泄露风险。

**DashScope 临时 Token API**：
- 端点：`POST https://dashscope.aliyuncs.com/api/v1/tokens?expire_in_seconds={ttl}`
- 认证：`Authorization: Bearer {永久API Key}`
- 响应：`{"token":"st-****","expires_at":1744080369}`

### D2: LLM 连接方式 — Server 代理

**选择**：LLM 请求全部经过 Server，不让客户端直接调用。

**理由**：
- Prompt 模板需要集中管理和版本化（`resources/prompts/`）
- 降级路由需要服务端协调（qwen-turbo → qwen-plus）
- 请求量小（平均每用户每天 1-2 次 LLM 调用），Server 负载可忽略
- 未来 A/B 测试、成本追踪需要服务端控制

**API 格式**：使用 DashScope OpenAI 兼容接口（`/compatible-mode/v1/chat/completions`），便于未来切换其他 OpenAI 兼容 Provider。

### D3: NLP 策略 — 客户端本地优先 + Server LLM 兜底

**选择**：本地规则引擎优先解析，失败时才调用 Server LLM。

**备选方案**：
| 方案 | 离线可用 | 成本 | 准确率 |
|------|---------|------|--------|
| A. 纯 LLM | 否 | 高 | 最高 |
| B. 本地优先 + LLM 兜底（选定） | 是（基础） | 低 | 高 |
| C. 纯本地规则 | 是 | 零 | 中 |

**理由**：PRD 要求离线可用基础能力。方案 B 兼顾成本和准确率 —— 简单输入（"午饭35"）本地即可解析，复杂输入（"上周三和朋友在太古里吃了个日料688"）交给 LLM。预估 70% 输入可本地解析。

### D4: Server 技术栈 — Kotlin + Spring Boot 3.5.x

**选择**：Kotlin 1.9.x + Spring Boot 3.5.x + Gradle KTS + Java 17

**理由**：
- 项目已配置 Spring Boot + Kotlin 技能栈（.skillsrc）
- Spring Boot 企业级成熟度高，丰富的生态（Actuator、WebClient、Validation）
- Kotlin 协程原生支持 suspend 函数，与 WebClient 异步模型契合
- Gradle KTS 与 Kotlin 代码一致的 DSL 体验

### D5: 客户端语音状态机 — 四态设计

**选择**：IDLE → LISTENING → RECOGNIZING → CONFIRMING

| 状态 | 麦克风 | VAD | ASR | 说明 |
|------|--------|-----|-----|------|
| IDLE | 关 | 关 | 关 | 首页，未进入语音模式 |
| LISTENING | 开 | 运行 | 关 | 等待用户说话，云端零消耗 |
| RECOGNIZING | 开 | 运行 | 连接 | 正在识别，实时显示文字 |
| CONFIRMING | 开 | 运行 | 关 | 展示解析结果，等待确认 |

**关键参数**（来自 PRD）：
- VAD 检测阈值：0.5
- 语音起始缓冲：300ms
- 静音判定时长：800ms
- 最小语音时长：500ms（防噪音误触）
- 超时退出：3 分钟无操作

### D6: 限流策略 — IP 维度令牌桶

**选择**：Bucket4j 令牌桶，按 IP + 端点分组限流。

**理由**：Phase 2 无用户体系，IP 是最简可行的限流维度。默认 ASR 30 次/分钟、LLM 60 次/分钟，通过 `application.yml` 可调。Phase 5 引入用户体系后升级为用户维度。

### D7: LLM Provider 抽象层

**选择**：`LlmProvider` 接口 + 配置化 Bean 注册。

```
LlmProvider (interface)
├── DashScopeLlmProvider (OpenAI-compatible)
└── [future] OpenAiProvider / AnthropicProvider / ...
```

**路由策略**：primary → fallback 降级链。当前配置：qwen-turbo（快速、低价）→ qwen-plus（强力、兜底）。通过 `application.yml` 的 `dashscope.llm.primary-model` 和 `fallback-model` 切换。

## Directory Structure

### Server（已实现）

```
voice-note-server/src/main/kotlin/com/suikouji/server/
├── VoiceNoteServerApplication.kt
├── config/
│   ├── DashScopeProperties.kt        # DashScope 配置
│   ├── RateLimitProperties.kt        # 限流配置
│   ├── WebClientConfig.kt            # HTTP 客户端 Bean
│   └── WebMvcConfig.kt               # 拦截器注册
├── asr/
│   ├── AsrTokenController.kt         # POST /api/v1/asr/token
│   ├── AsrTokenService.kt            # 调用 DashScope Token API
│   └── AsrTokenResponse.kt           # 响应 DTO
├── llm/
│   ├── LlmController.kt              # POST /api/v1/llm/parse-transaction
│   ├── LlmService.kt                 # 编排解析 + 降级
│   ├── provider/
│   │   ├── LlmProvider.kt            # 抽象接口
│   │   ├── DashScopeLlmProvider.kt   # OpenAI 兼容实现
│   │   └── LlmProviderConfig.kt      # Bean 注册
│   ├── prompt/
│   │   └── PromptManager.kt          # Prompt 模板加载
│   └── dto/
│       ├── TransactionParseRequest.kt
│       └── TransactionParseResponse.kt
├── ratelimit/
│   └── RateLimitInterceptor.kt       # 令牌桶限流
└── api/
    ├── GlobalExceptionHandler.kt      # 全局异常处理
    └── dto/
        └── ErrorResponse.kt           # 标准错误响应
```

### Client（已实现）

```
voice-note-client/lib/
├── core/
│   ├── network/                                # 网络层
│   │   ├── api_client.dart                     # dio 封装 + RetryInterceptor
│   │   ├── api_config.dart                     # Server URL 配置
│   │   ├── network_status_service.dart         # 网络状态检测（connectivity_plus）
│   │   ├── interceptors/
│   │   │   ├── error_interceptor.dart          # 统一错误解析
│   │   │   ├── logging_interceptor.dart        # Debug 日志
│   │   │   └── retry_interceptor.dart          # 指数退避重试（瞬态错误）
│   │   └── dto/
│   │       ├── asr_token_response.dart
│   │       ├── transaction_parse_request.dart
│   │       └── transaction_parse_response.dart
│   └── di/
│       └── network_providers.dart              # apiClient/apiConfig/networkStatus/sharedPreferences providers
├── features/
│   └── voice/                                  # 语音模块
│       ├── data/
│       │   ├── asr_repository.dart             # ASR Token 获取 + 缓存
│       │   ├── asr_websocket_service.dart      # DashScope ASR WebSocket（断连通知）
│       │   ├── audio_capture_service.dart      # PCM16 16kHz 音频采集
│       │   ├── llm_repository.dart             # LLM 解析请求
│       │   ├── local_nlp_engine.dart           # 本地规则引擎编排（输入校验 + 截断）
│       │   ├── vad_service.dart                # Silero VAD 封装
│       │   ├── voice_transaction_service.dart  # ParseResult → SQLite 持久化
│       │   └── nlp/                            # NLP 子提取器
│       │       ├── amount_extractor.dart
│       │       ├── category_matcher.dart
│       │       ├── date_extractor.dart
│       │       └── type_inferrer.dart
│       ├── domain/
│       │   ├── voice_state.dart                # 四态状态机枚举
│       │   ├── parse_result.dart               # 统一解析结果模型（含 copyWith）
│       │   ├── voice_orchestrator.dart         # 核心编排器（Audio→VAD→ASR→NLP 管线 + ASR 重连）
│       │   ├── nlp_orchestrator.dart           # 本地优先 → LLM 兜底（离线感知）
│       │   ├── voice_correction_handler.dart   # 语音纠错意图识别
│       │   └── voice_exceptions.dart           # 域级异常定义
│       └── presentation/
│           ├── voice_recording_screen.dart      # 主 UI（离线 Banner/处理指示器/SnackBar/引导）
│           ├── widgets/
│           │   ├── voice_animation.dart         # 脉冲/声波/思考动画（Semantics）
│           │   ├── confirmation_card.dart       # 确认卡片（动画入场/来源徽标/类型切换/Semantics）
│           │   ├── chat_bubble.dart             # 对话气泡（4 种消息类型/Semantics）
│           │   ├── mode_switcher.dart           # 自动/按住/键盘切换
│           │   ├── field_editor.dart            # 统一字段编辑 bottom sheet
│           │   └── voice_tutorial_dialog.dart   # 首次使用引导（3 页 PageView）
│           └── providers/
│               ├── voice_session_provider.dart  # 状态管理 + Delegate 实现 + 触觉反馈
│               ├── voice_settings_provider.dart # 输入模式偏好
│               ├── voice_providers.dart         # DI 层：所有语音服务注册
│               └── quick_suggestions_provider.dart # 历史数据动态快捷词
```

## Risks / Trade-offs

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| DashScope 临时 Token 服务不可用 | 语音功能完全不可用 | 客户端降级到手动输入；Server 健康检查 + 告警 |
| VAD 在嘈杂环境误触发 | 不必要的 ASR 调用增加成本 | 500ms 最小语音时长过滤；连续误触 3 次建议切换按住说话模式 |
| LLM 解析结果不准确 | 用户需要手动纠正 | 确认卡片 UI 支持各字段编辑；提供语音纠错（"不对，改成XX"） |
| 单台 Server 宕机 | 语音功能中断 | 手动记账不受影响（local-first）；Phase 5 可扩展多实例 |
| IP 限流被绕过（NAT/VPN） | 恶意用户消耗配额 | Phase 5 升级为用户维度限流；当前阶段风险可控 |
| 本地规则引擎覆盖率不足 | 过多请求走 LLM 增加成本 | 初期收集高频输入模式，持续优化规则覆盖率 |

## Migration Plan

1. **Server 部署**：单台阿里云 ECS（2C4G），Docker 部署，Nginx 反向代理 + HTTPS
2. **客户端发版策略**：语音功能作为新页面入口，不影响现有手动记账流程，可灰度发布
3. **回滚方案**：客户端隐藏语音入口即可回退到纯手动模式；Server 停机不影响核心记账
4. **监控**：Spring Actuator 健康检查 + DashScope 调用量/延迟/错误率监控

## Open Questions (Resolved)

1. ~~**Silero VAD Flutter 包的成熟度如何？**~~ → 已集成 `vad` 包，通过 `VadService` 封装，iOS/Android 均可运行
2. ~~**DashScope ASR WebSocket 的 Flutter 客户端最佳实践？**~~ → `web_socket_channel` 支持 DashScope 认证，已实现 `AsrWebSocketService` 含自动重连
3. ~~**本地规则引擎的初始覆盖率目标？**~~ → 已实现 4 个提取器（金额/日期/分类/类型），覆盖 PRD 定义的所有关键词映射，预估可本地解析 70%+ 输入

## Decisions Added During Implementation

### D8: VoiceOrchestrator Delegate 模式

**选择**：`VoiceOrchestratorDelegate` 接口解耦编排器与 UI 状态管理。

**理由**：
- Orchestrator 管理音频/网络等底层服务，不应直接依赖 Riverpod/UI 框架
- Delegate 回调（onSpeechDetected/onFinalText/onError 等）让 UI 层自由决定如何反映状态
- 支持单元测试中使用 Fake Delegate 验证管线逻辑

### D9: 本地优先 NLP + 离线感知

**选择**：`NlpOrchestrator` 注入 `NetworkStatusService`，离线时跳过 LLM 兜底。

**理由**：避免离线时触发无意义的 HTTP 请求和超时等待，直接返回本地解析结果。

### D10: HTTP 重试与 WebSocket 重连分离策略

**选择**：
- HTTP API：`RetryInterceptor` 在 Dio 层自动重试瞬态错误（超时、5xx），指数退避（1s→2s→4s），不重试 4xx
- WebSocket ASR：`VoiceOrchestrator` 层感知 ASR 断连事件，指数退避重连（最多 3 次），失败后降级到 LISTENING 状态

**理由**：HTTP 和 WebSocket 的故障模式不同，需要不同的恢复策略。HTTP 重试对调用方透明；WebSocket 重连需要编排器协调状态机。
