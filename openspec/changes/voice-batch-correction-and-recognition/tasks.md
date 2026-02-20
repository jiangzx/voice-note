## 1. 服务端：批量解析 Prompt & 响应升级

- [x] 1.1 升级 `transaction-parse.txt` Prompt 模板：指导 LLM 返回 `{"transactions": [...]}` 格式，包含分割规则说明和 **3-5 个 few-shot 示例**（单笔、双笔、多笔混合收支、共享日期继承）。目标文件：`voice-note-server/src/main/resources/prompts/transaction-parse.txt`
- [x] 1.2 新增 `TransactionBatchParseResponse` DTO（包含 `transactions: List<TransactionParseResponse>` + `model`）。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/dto/TransactionBatchParseResponse.kt`
- [x] 1.3 修改 `LlmService.parseTransaction` 返回 `TransactionBatchParseResponse`，解析 LLM 返回的 JSON 数组。添加轻校验（JSON 格式 + transactions 为数组）。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/LlmService.kt`
- [x] 1.4 修改 `LlmController` 的 `parse-transaction` 端点响应为数组格式。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/LlmController.kt`
- [x] 1.5 编写 Server 单元测试：多笔解析、单笔解析、顺序保持、few-shot 效果验证（mock LLM）。目标文件：`voice-note-server/src/test/kotlin/com/suikouji/server/llm/LlmServiceTest.kt`

## 2. 服务端：纠正接口 & Prompt（batch-aware）

- [x] 2.1 创建 `correction-dialogue.txt` Prompt 模板：支持 batch context 列表、序号映射规则、描述词匹配指引。添加 **3-5 个 batch few-shot 示例**（序号定位、描述词定位、多笔修正、确认、取消、追加）。目标文件：`voice-note-server/src/main/resources/prompts/correction-dialogue.txt`
- [x] 2.2 新增 `TransactionCorrectionRequest` DTO（包含 `currentBatch: List<BatchItem>`、`correctionText`、`context`）和 `TransactionCorrectionResponse` DTO（包含 `corrections: List<CorrectionItem>`、`intent`（枚举含 `append`）、`confidence`、`model`）。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/dto/TransactionCorrectionRequest.kt`、`voice-note-server/src/main/kotlin/com/suikouji/server/llm/dto/TransactionCorrectionResponse.kt`
- [x] 2.3 在 `LlmService` 中新增 `correctTransaction` 方法：组装 Prompt（batch items 填入模板）+ 调用 LLM + 解析 JSON + 轻校验（JSON 格式 + intent 枚举 + index 范围）。复用 primary/fallback 双模型容错。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/LlmService.kt`
- [x] 2.4 在 `LlmController` 中新增 `POST /api/v1/llm/correct-transaction` 端点。复用现有 API Key 认证和 rate-limit。目标文件：`voice-note-server/src/main/kotlin/com/suikouji/server/llm/LlmController.kt`
- [x] 2.5 编写 Server 单元测试：batch 纠正（序号定位、描述词定位、多笔修正、append、index 越界过滤、单笔兼容）。目标文件：`voice-note-server/src/test/kotlin/com/suikouji/server/llm/LlmServiceTest.kt`

## 3. API Contract 更新

- [x] 3.1 在 `voice-note-api.yaml` 中更新 `parse-transaction` 响应 schema 为数组格式。目标文件：`api-contracts/voice-note-api.yaml`
- [x] 3.2 在 `voice-note-api.yaml` 中新增 `correct-transaction` 接口 schema（request: currentBatch + correctionText + context，response: corrections + intent + confidence + model）。目标文件：`api-contracts/voice-note-api.yaml`

## 4. 客户端：DraftBatch 数据模型

- [x] 4.1 创建 `DraftTransaction` 和 `DraftBatch` 不可变数据模型。`DraftBatch` 提供 `updateItem`、`confirmItem`、`cancelItem`、`confirmAll`、`cancelAll`、`pendingItems`、`confirmedItems`、`allResolved` 等方法。目标文件：`voice-note-client/lib/features/voice/domain/draft_batch.dart`
- [x] 4.2 编写 `DraftBatch` 单元测试：创建、updateItem、confirmItem、cancelItem、confirmAll、cancelAll、自动提交判定、单笔兼容。目标文件：`voice-note-client/test/features/voice/domain/draft_batch_test.dart`

## 5. 客户端：网络层升级

- [x] 5.1 新增 `TransactionBatchParseResponse` 客户端 DTO（对应 Server 数组响应）。目标文件：`voice-note-client/lib/core/network/dto/transaction_batch_parse_response.dart`
- [x] 5.2 修改 `LlmRepository.parseTransaction` 返回 `List<ParseResult>`（从数组响应映射）。目标文件：`voice-note-client/lib/features/voice/data/llm_repository.dart`
- [x] 5.3 新增 `TransactionCorrectionRequest` 和 `TransactionCorrectionResponse` 客户端 DTO。目标文件：`voice-note-client/lib/core/network/dto/transaction_correction_request.dart`、`voice-note-client/lib/core/network/dto/transaction_correction_response.dart`
- [x] 5.4 在 `LlmRepository` 中新增 `correctTransaction` 方法：发送 `currentBatch` 数组（仅 pending items，重编号），接收 `corrections` 数组。目标文件：`voice-note-client/lib/features/voice/data/llm_repository.dart`
- [x] 5.5 编写网络层单元测试（batch parse、batch correct、单笔兼容）。目标文件：`voice-note-client/test/features/voice/data/llm_repository_test.dart`

## 6. 客户端：增强本地纠正规则

- [x] 6.1 扩展 `VoiceCorrectionHandler._correctionPrefixes` 关键词：新增 `修改为`, `改为`, `应该是`, `不是`, `搞错了`, `弄错了`。新增字段关键词 `收入`, `支出`。新增序号匹配模式（「确认第X笔」「删掉第X笔」「取消第X笔」）。目标文件：`voice-note-client/lib/features/voice/domain/voice_correction_handler.dart`
- [x] 6.2 在 `applyCorrection` 中新增交易类型修正：检测 `收入`→INCOME / `支出`→EXPENSE。目标文件：`voice-note-client/lib/features/voice/domain/voice_correction_handler.dart`
- [x] 6.3 编写单元测试覆盖所有新增关键词、类型修正、序号匹配、优先级。目标文件：`voice-note-client/test/features/voice/domain/voice_correction_handler_test.dart`

## 7. 客户端：NLP 层升级

- [x] 7.1 修改 `NlpOrchestrator.parse` 返回 `List<ParseResult>`：在线时从 LLM batch 响应映射，离线时本地 NLP 返回单元素列表。目标文件：`voice-note-client/lib/features/voice/domain/nlp_orchestrator.dart`
- [x] 7.2 在 `NlpOrchestrator` 中新增 `correct(text, draftBatch)` 方法：在线时调用 `LlmRepository.correctTransaction`（3 秒超时，超时降级到本地规则），离线时调用 `VoiceCorrectionHandler.applyCorrection`。返回前应用 confidence 阈值（< 0.7 → unclear）。目标文件：`voice-note-client/lib/features/voice/domain/nlp_orchestrator.dart`
- [x] 7.3 编写 NLP 层单元测试（batch parse、batch correct、离线降级为单笔、超时降级、低 confidence 回退）。目标文件：`voice-note-client/test/features/voice/domain/nlp_orchestrator_test.dart`

## 8. 客户端：编排器重构

- [x] 8.1 在 `VoiceOrchestrator` 中新增 `DraftBatch? _draftBatch` 字段。修改 `_parseAndDeliver` 从 `List<ParseResult>` 创建 `DraftBatch`。修改 Delegate `onFinalText` 参数为 `(String, DraftBatch)`。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.2 重构 `_handleConfirmingSpeech` 的本地规则层：保持 confirm/cancel/exit/continue 规则，新增序号匹配模式（confirmItem/cancelItem），correction/newInput 交给 LLM。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.3 实现 LLM 纠正调用逻辑：TTS「好的，正在修改...」→ 调用 `NlpOrchestrator.correct` → 根据 intent 执行操作。遍历 `corrections[]` 逐条更新 DraftBatch。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.4 实现自动提交逻辑：所有 item 非 pending 时，调用 `VoiceTransactionService.saveBatch(confirmedItems)`，清空 `_draftBatch`。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.5 实现 `intent: "append"` 处理逻辑：构造新 DraftTransaction 追加到 DraftBatch 尾部，检查 10 笔上限。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.6 实现纠正时 cancelled/confirmed items 过滤和 index 重编号：构建 pending items 映射表，发送前重编号，收到后映射回原始 index。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [x] 8.7 确保 confirm/cancel/continueRecording/exit 分支正确操作 `_draftBatch`（全部/逐条），完成后清空。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

## 9. 客户端：VoiceTransactionService 批量保存

- [x] 9.1 新增 `saveBatch(List<ParseResult>)` 方法，在单事务中保存多笔交易。任一笔失败 SHALL 回滚全部。目标文件：`voice-note-client/lib/features/voice/data/voice_transaction_service.dart`
- [x] 9.2 编写 `saveBatch` 单元测试（全部成功、部分失败回滚）。目标文件：`voice-note-client/test/features/voice/data/voice_transaction_service_test.dart`

## 10. 客户端：TTS 模板升级

- [x] 10.1 新增纠正相关模板：`correctionLoading`（「好的，正在修改...」）、`correctionConfirm`（修正成功播报）、`correctionFailed`（「没听清要改什么，请再说一次」）。目标文件：`voice-note-client/lib/core/tts/tts_templates.dart`
- [x] 10.2 新增多笔播报模板：`batchConfirmation`（逐条播报，2-5笔）、`batchSummary`（摘要播报，6-10笔）、`batchSaved`（保存成功播报）、`batchItemCancelled`（逐条取消反馈）、`batchTargetedCorrection`（定点修正反馈）、`batchAppended`（追加新笔播报）、`batchLimitReached`（超限提示）。目标文件：`voice-note-client/lib/core/tts/tts_templates.dart`
- [x] 10.3 修改编排器中 TTS 调用，根据 `DraftBatch.items.length` 选择单笔或多笔模板。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

## 11. 客户端：确认卡片 UI 升级

- [x] 11.1 创建 `BatchConfirmationCard` widget 主体结构：Header（source badge + pending count badge）、可滚动 item 列表、Summary bar（合计金额）、Action bar（全部确认/取消）。≤3 笔不滚动，4+ 笔列表区域固定高度可滚动。目标文件：`voice-note-client/lib/features/voice/presentation/widgets/batch_confirmation_card.dart`
- [x] 11.2 实现 `_BatchItemRow` widget：序号 + 类型 Chip + 金额 + 分类 + 描述。状态可视化：pending（透明）、confirmed（primaryContainer + ✓）、cancelled（errorContainer + 删除线 + 半透明）。状态变化动画（背景渐变 + 图标 scale-in，250ms）。目标文件：同上
- [x] 11.3 实现 Swipe 手势：左滑取消（errorContainer 背景 + 垃圾桶图标）、右滑确认（primaryContainer + ✓）。触发阈值 25% 行宽。已处理行禁用滑动。HapticFeedback 反馈。目标文件：同上
- [x] 11.4 实现纠正更新动画：变化字段黄色 highlight 闪烁（200ms → 消退 300ms）+ AnimatedSwitcher。实现新笔追加动画：底部 slide-in 250ms。实现全部确认动画：stagger 50ms 逐行确认 → 卡片 fade-out。目标文件：同上
- [x] 11.5 实现 LLM 处理中 shimmer 效果：对应行显示 shimmer loading 效果，LLM 返回后停止并触发更新动画。目标文件：同上
- [x] 11.6 实现行点击展开详情视图：展开为完整字段编辑视图，350ms easeInOutCubic 动画。目标文件：同上
- [x] 11.7 修改 `VoiceSessionState`：`parseResult: ParseResult?` 升级为 `draftBatch: DraftBatch?`。修改 `VoiceSessionNotifier`：当 `draftBatch.items.length > 1` 时展示 `BatchConfirmationCard`，否则展示现有 `ConfirmationCard`。目标文件：`voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`
- [x] 11.8 修改 `voice_recording_screen.dart`：CONFIRMING 状态文本改为「请确认或说出要修改的内容」（多笔时）。根据 draftBatch 选择展示单笔/多笔卡片。目标文件：`voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`
- [x] 11.9 实现 Accessibility：每行 Semantics 标签、VoiceOver/TalkBack 自定义操作替代滑动、pending count live region。目标文件：同上
- [x] 11.10 实现混合操作冲突处理：滑动中延迟语音纠正、编辑弹窗中忽略语音纠正并 TTS 提示、详情展开中收到 confirmAll 先关闭详情。目标文件：同上
- [x] 11.11 编写 `BatchConfirmationCard` widget 测试：列表渲染、swipe 手势、状态可视化、动画触发、单笔兼容。目标文件：`voice-note-client/test/features/voice/presentation/widgets/batch_confirmation_card_test.dart`

## 12. 编排器完整逻辑测试

- [x] 12.1 测试：多笔输入 → DraftBatch 创建（4 笔 pending）。目标文件：`voice-note-client/test/features/voice/domain/voice_orchestrator_test.dart`
- [x] 12.2 测试：全部确认 → saveBatch 调用 → DraftBatch 清空。目标文件：同上
- [x] 12.3 测试：定点纠正（序号）→ LLM 返回 corrections → 对应 item 更新 + Delegate 通知。目标文件：同上
- [x] 12.4 测试：定点纠正（描述词）→ LLM 返回 corrections → 对应 item 更新。目标文件：同上
- [x] 12.5 测试：逐条取消 → cancelItem → 剩余 pending 检查 → TTS 播报。目标文件：同上
- [x] 12.6 测试：混合完成（部分 confirm + 部分 cancel）→ 自动提交 confirmed → 清空。目标文件：同上
- [x] 12.7 测试：单笔 batch（size==1）行为与原单笔逻辑一致。目标文件：同上
- [x] 12.8 测试：离线降级为单笔 + TTS 提示。目标文件：同上
- [x] 12.9 测试：LLM 超时 → 降级本地规则纠正。目标文件：同上
- [x] 12.10 测试：多笔 TTS 播报格式（2-5笔逐条 vs 6+笔摘要）。目标文件：同上
- [x] 12.11 测试：CONFIRMING 态追加新笔 → DraftBatch 尾部新增 item + TTS 播报。目标文件：同上
- [x] 12.12 测试：追加超限（>10 笔）→ 拒绝并 TTS 提示。目标文件：同上
- [x] 12.13 测试：纠正时 cancelled items 排除 + index 重编号 + 映射回原始 index。目标文件：同上
- [x] 12.14 测试：LLM 二次判定为确认 → 执行确认流程。目标文件：同上
- [x] 12.15 测试：correction 发起时 TTS 立即播报「好的，正在修改...」。目标文件：同上
- [x] 12.16 测试：LLM 返回 confidence < 0.7 → 视为 unclear。目标文件：同上
- [x] 12.17 测试：多次纠正累积（先改类型再改金额）。目标文件：同上
- [x] 12.18 测试：confirm/cancel/continue 清空 DraftBatch。目标文件：同上

## 13. 集成测试 & 回归验证

- [x] 13.1 运行全量 Server 测试，确认 parse-transaction 和 correct-transaction 升级无回归。
- [x] 13.2 运行全量 Client 测试，确认单笔场景无回归。
- [ ] 13.3 端到端手动测试：使用真机或模拟器测试多笔语音输入 → 确认 → 纠正 → 保存完整流程。
