## 1. Server — 补充测试与完善（voice-note-server 骨架已创建）

- [x] 1.1 ASR Token Service 单元测试 — 验证 Token 生成、TTL 配置、DashScope API 调用  
  `voice-note-server/src/test/kotlin/com/suikouji/server/asr/AsrTokenServiceTest.kt`

- [x] 1.2 LLM Service 单元测试 — 验证 primary/fallback 降级、JSON 提取、Prompt 注入  
  `voice-note-server/src/test/kotlin/com/suikouji/server/llm/LlmServiceTest.kt`

- [x] 1.3 DashScope LLM Provider 单元测试 — 验证 OpenAI 兼容接口调用、响应解析  
  `voice-note-server/src/test/kotlin/com/suikouji/server/llm/provider/DashScopeLlmProviderTest.kt`

- [x] 1.4 Prompt Manager 单元测试 — 验证模板加载、缓存、缺失文件异常  
  `voice-note-server/src/test/kotlin/com/suikouji/server/llm/prompt/PromptManagerTest.kt`

- [x] 1.5 Rate Limit Interceptor 单元测试 — 验证 IP 限流、端点分组、429 响应  
  `voice-note-server/src/test/kotlin/com/suikouji/server/ratelimit/RateLimitInterceptorTest.kt`

- [x] 1.6 Server 集成测试 — ASR Token 端点端到端、LLM 解析端点端到端（Mock DashScope）  
  `voice-note-server/src/test/kotlin/com/suikouji/server/ApiIntegrationTest.kt`

## 2. Client — 网络层（core/network）

- [x] 2.1 添加 dio 依赖到 pubspec.yaml  
  `voice-note-client/pubspec.yaml`

- [x] 2.2 实现 ApiConfig — Server Base URL 管理、超时配置、环境切换  
  `voice-note-client/lib/core/network/api_config.dart`

- [x] 2.3 实现 ApiClient — dio 封装、JSON 序列化配置、请求拦截器注册  
  `voice-note-client/lib/core/network/api_client.dart`

- [x] 2.4 实现错误拦截器 — 统一 4xx/5xx 解析、NetworkUnavailableError、RateLimitError、LlmParseError  
  `voice-note-client/lib/core/network/interceptors/error_interceptor.dart`

- [x] 2.5 实现日志拦截器 — Debug 模式请求/响应日志  
  `voice-note-client/lib/core/network/interceptors/logging_interceptor.dart`

- [x] 2.6 实现 DTO — AsrTokenResponse、TransactionParseRequest、TransactionParseResponse  
  `voice-note-client/lib/core/network/dto/asr_token_response.dart`  
  `voice-note-client/lib/core/network/dto/transaction_parse_request.dart`  
  `voice-note-client/lib/core/network/dto/transaction_parse_response.dart`

- [x] 2.7 注册 Riverpod Provider — apiConfigProvider、apiClientProvider  
  `voice-note-client/lib/core/di/network_providers.dart`

- [x] 2.8 网络层单元测试 — ApiClient 请求/响应、错误拦截器、DTO 序列化  
  `voice-note-client/test/core/network/api_client_test.dart`  
  `voice-note-client/test/core/network/interceptors/error_interceptor_test.dart`

## 3. Client — 本地 NLP 规则引擎（features/voice/data）

- [x] 3.1 实现金额提取器 — 阿拉伯数字、带单位、货币符号正则匹配  
  `voice-note-client/lib/features/voice/data/nlp/amount_extractor.dart`

- [x] 3.2 实现日期提取器 — 今天/昨天/前天、星期引用、绝对日期解析  
  `voice-note-client/lib/features/voice/data/nlp/date_extractor.dart`

- [x] 3.3 实现分类匹配器 — 关键词→分类映射表、自定义分类集成、模糊匹配  
  `voice-note-client/lib/features/voice/data/nlp/category_matcher.dart`

- [x] 3.4 实现类型推断器 — 支出/收入/转账动词关键词判定  
  `voice-note-client/lib/features/voice/data/nlp/type_inferrer.dart`

- [x] 3.5 实现 LocalNlpEngine — 编排上述提取器、输出 ParseResult、判定解析完整性  
  `voice-note-client/lib/features/voice/data/local_nlp_engine.dart`

- [x] 3.6 NLP 引擎单元测试 — 各提取器覆盖 PRD 中定义的关键词映射表和场景  
  `voice-note-client/test/features/voice/data/nlp/amount_extractor_test.dart`  
  `voice-note-client/test/features/voice/data/nlp/date_extractor_test.dart`  
  `voice-note-client/test/features/voice/data/nlp/category_matcher_test.dart`  
  `voice-note-client/test/features/voice/data/nlp/type_inferrer_test.dart`  
  `voice-note-client/test/features/voice/data/local_nlp_engine_test.dart`

## 4. Client — 语音数据层（features/voice/data）

- [x] 4.1 实现 AsrRepository — ASR Token 获取（调用 Server API）、Token 缓存与刷新  
  `voice-note-client/lib/features/voice/data/asr_repository.dart`

- [x] 4.2 实现 LlmRepository — 交易文本解析请求（调用 Server API）、上下文构建  
  `voice-note-client/lib/features/voice/data/llm_repository.dart`

- [x] 4.3 AsrRepository / LlmRepository 单元测试  
  `voice-note-client/test/features/voice/data/asr_repository_test.dart`  
  `voice-note-client/test/features/voice/data/llm_repository_test.dart`

## 5. Client — 语音域层（features/voice/domain）

- [x] 5.1 定义 VoiceState 枚举 — IDLE、LISTENING、RECOGNIZING、CONFIRMING + 关联数据  
  `voice-note-client/lib/features/voice/domain/voice_state.dart`

- [x] 5.2 定义 ParseResult 模型 — 统一本地和 LLM 解析结果的数据模型  
  `voice-note-client/lib/features/voice/domain/parse_result.dart`

- [x] 5.3 实现 VoiceSession — 状态机管理、VAD 事件处理、超时管理（3min 退出 / 2m30s 预警）  
  `voice-note-client/lib/features/voice/domain/voice_session.dart`

- [x] 5.4 实现 NlpOrchestrator — 本地引擎优先 → LLM 兜底策略编排、解析完整性判定  
  `voice-note-client/lib/features/voice/domain/nlp_orchestrator.dart`

- [x] 5.5 实现 VoiceCorrectionHandler — 纠错意图识别（"不对"/"改一下"/"取消"）、字段定位  
  `voice-note-client/lib/features/voice/domain/voice_correction_handler.dart`

- [x] 5.6 域层单元测试 — 状态机流转、NLP 编排、纠错逻辑  
  `voice-note-client/test/features/voice/domain/voice_session_test.dart`  
  `voice-note-client/test/features/voice/domain/nlp_orchestrator_test.dart`  
  `voice-note-client/test/features/voice/domain/voice_correction_handler_test.dart`

## 6. Client — VAD 与 ASR 集成（features/voice/data）

- [x] 6.1 添加 vad 和 web_socket_channel 依赖到 pubspec.yaml  
  `voice-note-client/pubspec.yaml`

- [x] 6.2 实现 VadService — Silero VAD 初始化、事件流（onSpeechStart/onSpeechEnd）、参数配置  
  `voice-note-client/lib/features/voice/data/vad_service.dart`

- [x] 6.3 实现 AsrWebSocketService — DashScope WebSocket 连接管理、Token 认证、实时结果流  
  `voice-note-client/lib/features/voice/data/asr_websocket_service.dart`

- [x] 6.4 实现 AudioCaptureService — 麦克风音频流采集、音频格式配置  
  `voice-note-client/lib/features/voice/data/audio_capture_service.dart`

- [x] 6.5 VAD / ASR / Audio 服务单元测试  
  `voice-note-client/test/features/voice/data/vad_service_test.dart`  
  `voice-note-client/test/features/voice/data/asr_websocket_service_test.dart`

## 7. Client — 语音交互 UI（features/voice/presentation）

- [x] 7.1 实现 VoiceAnimation Widget — 脉冲呼吸（LISTENING）、声波扩散（RECOGNIZING）、跳动（处理中）、打勾（成功）  
  `voice-note-client/lib/features/voice/presentation/widgets/voice_animation.dart`

- [x] 7.2 实现 ConfirmationCard Widget — 交易字段展示、各字段可点击编辑、金额变更动画  
  `voice-note-client/lib/features/voice/presentation/widgets/confirmation_card.dart`

- [x] 7.3 实现 ChatBubble Widget — 助手气泡（左）、用户气泡（右）、自动滚动  
  `voice-note-client/lib/features/voice/presentation/widgets/chat_bubble.dart`

- [x] 7.4 实现 ModeSwitcher Widget — 自动模式/按住说话/键盘输入切换控件  
  `voice-note-client/lib/features/voice/presentation/widgets/mode_switcher.dart`

- [x] 7.5 实现 VoiceRecordingScreen — 组合所有 Widget、绑定 VoiceSession Provider  
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 7.6 实现 Riverpod Providers — voiceSessionProvider、voiceSettingsProvider  
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`  
  `voice-note-client/lib/features/voice/presentation/providers/voice_settings_provider.dart`

- [x] 7.7 语音 UI Widget 测试  
  `voice-note-client/test/features/voice/presentation/widgets/voice_animation_test.dart`  
  `voice-note-client/test/features/voice/presentation/widgets/confirmation_card_test.dart`

## 8. Client — 路由与页面入口集成

- [x] 8.1 注册语音记账路由 — go_router 添加 /voice-recording 路由  
  `voice-note-client/lib/app/router.dart`

- [x] 8.2 修改首页 — 新增语音记账 FAB 入口（大号麦克风图标），导航至 /voice-recording  
  `voice-note-client/lib/features/home/presentation/home_screen.dart`

- [x] 8.3 修改设置页 — 新增"语音输入"设置分组（默认输入模式选择）  
  `voice-note-client/lib/features/settings/presentation/settings_screen.dart`

- [x] 8.4 修改设置页 — 新增"高级设置"区域（Server 地址配置）  
  `voice-note-client/lib/features/settings/presentation/settings_screen.dart`

- [x] 8.5 路由与页面集成测试  
  `voice-note-client/test/features/home/presentation/home_screen_test.dart`  
  `voice-note-client/test/features/settings/presentation/settings_screen_test.dart`

## 9. Client — 语音管线编排（原计划外新增）

- [x] 9.1 实现 VoiceOrchestrator — 串联 AudioCapture → VAD → ASR → NLP 完整管线  
  `voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

- [x] 9.2 实现 VoiceOrchestratorDelegate — Delegate 模式解耦编排器与 UI 状态管理  
  `voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

- [x] 9.3 实现 voice_providers.dart — Riverpod DI 层注册所有语音服务  
  `voice-note-client/lib/features/voice/presentation/providers/voice_providers.dart`

- [x] 9.4 VoiceOrchestrator 单元测试 — 状态机全路径 + ASR 重连场景  
  `voice-note-client/test/features/voice/domain/voice_orchestrator_test.dart`

## 10. Client — 交易保存逻辑（原计划外新增）

- [x] 10.1 实现 VoiceTransactionService — ParseResult → TransactionEntity 映射、分类模糊匹配、账户解析  
  `voice-note-client/lib/features/voice/data/voice_transaction_service.dart`

- [x] 10.2 集成保存到 VoiceSessionNotifier — confirmTransaction/onContinueRecording 调用 save()  
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 10.3 VoiceTransactionService 单元测试 — 内存数据库验证各映射场景  
  `voice-note-client/test/features/voice/data/voice_transaction_service_test.dart`

## 11. Client — 错误处理与韧性（原计划外新增）

- [x] 11.1 定义域级异常 — AudioCaptureException、VadServiceException、AsrTokenException、LlmParseException、VoiceSaveException  
  各 data/ 文件中定义

- [x] 11.2 全管线 try-catch — AudioCapture/VAD/ASR/NLP/Save 各层错误捕获与上报  
  `voice-note-client/lib/features/voice/data/*.dart`  
  `voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

- [x] 11.3 HTTP 重试拦截器 — 指数退避重试瞬态错误（连接超时、5xx），不重试 4xx  
  `voice-note-client/lib/core/network/interceptors/retry_interceptor.dart`

- [x] 11.4 ASR WebSocket 自动重连 — 意外断连后指数退避重连（最多 3 次）、Token 失效后刷新  
  `voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`  
  `voice-note-client/lib/features/voice/data/asr_websocket_service.dart`

- [x] 11.5 网络状态检测 — connectivity_plus 监控在线/离线状态、离线时仅使用本地 NLP  
  `voice-note-client/lib/core/network/network_status_service.dart`  
  `voice-note-client/lib/features/voice/domain/nlp_orchestrator.dart`

- [x] 11.6 本地 NLP 输入防护 — 空/超长输入校验（max 200 chars）  
  `voice-note-client/lib/features/voice/data/local_nlp_engine.dart`

- [x] 11.7 韧性模块单元测试  
  `voice-note-client/test/core/network/interceptors/retry_interceptor_test.dart`  
  `voice-note-client/test/core/network/network_status_service_test.dart`  
  `voice-note-client/test/features/voice/domain/nlp_orchestrator_test.dart`

## 12. Client — UI 交互增强（原计划外新增）

- [x] 12.1 Chat 消息类型系统 — ChatMessageType 枚举（normal/system/error/success）、视觉样式差异化  
  `voice-note-client/lib/features/voice/presentation/widgets/chat_bubble.dart`

- [x] 12.2 NLP 处理中指示器 — 加载动画 + 禁用输入  
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`  
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 12.3 确认卡片增强 — 动画入场（slide-up+fade）、识别来源徽标（Local/AI+置信度）、缺失字段红色高亮  
  `voice-note-client/lib/features/voice/presentation/widgets/confirmation_card.dart`

- [x] 12.4 收入/支出/转账类型切换 — 确认卡片金额行内联类型循环切换  
  `voice-note-client/lib/features/voice/presentation/widgets/confirmation_card.dart`

- [x] 12.5 字段编辑器 — 统一 bottom sheet 编辑（金额/分类/日期/账户/描述）  
  `voice-note-client/lib/features/voice/presentation/widgets/field_editor.dart`

- [x] 12.6 触觉反馈 — 语音检测/识别完成/保存成功失败/错误分级触觉  
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 12.7 保存结果 SnackBar — 浮动 SnackBar 提示保存成功/失败  
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 12.8 历史数据动态快捷词 — FutureProvider 按频率生成键盘模式快捷输入词  
  `voice-note-client/lib/features/voice/presentation/providers/quick_suggestions_provider.dart`

- [x] 12.9 首次使用引导 — 3 页 PageView 教程对话框（SharedPreferences 记录已读）  
  `voice-note-client/lib/features/voice/presentation/widgets/voice_tutorial_dialog.dart`

- [x] 12.10 无障碍支持 — Semantics 标签覆盖确认卡片、聊天气泡、录音控件、快捷词、引导  
  多个 presentation/ 文件

- [x] 12.11 离线模式 Banner — 网络断开时顶部提示横幅  
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 12.12 Server URL 配置对话框 — 带连接测试的专用编辑对话框  
  `voice-note-client/lib/features/settings/presentation/screens/settings_screen.dart`

## 13. Client — 端到端集成测试（原计划外新增）

- [x] 13.1 语音记账 E2E 测试 — 键盘输入 → 本地 NLP → SQLite 持久化完整链路  
  `voice-note-client/test/features/voice/voice_e2e_test.dart`

## 14. 端到端验证

- [ ] 14.1 Server 端到端验证 — 配置 DashScope API Key、启动 Server、验证 ASR Token 和 LLM 解析端点  
  `voice-note-server/` (手动验证)

- [ ] 14.2 Client-Server 联调 — 客户端语音记账完整链路（VAD → ASR → NLP → 确认 → 保存）  
  `voice-note-client/` + `voice-note-server/` (手动验证)

- [ ] 14.3 离线降级验证 — 断网时手动记账正常、语音功能提示切换手动输入  
  `voice-note-client/` (手动验证)
