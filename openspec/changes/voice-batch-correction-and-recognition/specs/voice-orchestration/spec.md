## MODIFIED Requirements

### Requirement: Delegate 模式解耦
编排器 SHALL 通过 VoiceOrchestratorDelegate 接口向 UI 层报告事件。Delegate SHALL 包含以下回调：onSpeechDetected（语音检测到）、onPartialText（中间识别结果）、onFinalText（最终文本+解析结果）、onDraftBatchUpdated（DraftBatch 变更通知）、onError（错误信息）、onContinueRecording（连续记账继续监听）。

`onFinalText` 的参数 SHALL 从 `(String text, ParseResult result)` 变更为 `(String text, DraftBatch batch)`，传递完整的草稿集合。新增 `onDraftBatchUpdated(DraftBatch batch)` 回调，用于纠正/逐条操作后通知 UI 刷新。

#### Scenario: Delegate 安全
- **WHEN** 异步回调（如 ASR 错误）在 Notifier 已释放后触发
- **THEN** UI 层 SHALL 通过 _sessionActive 标志忽略该回调，SHALL NOT 修改已释放的 state

#### Scenario: 纠正更新通知
- **WHEN** 编排器通过 LLM 纠正成功更新 DraftBatch 中某笔
- **THEN** 编排器 SHALL 调用 `Delegate.onDraftBatchUpdated(updatedBatch)` 通知 UI 刷新确认卡片

### Requirement: 交易确认与保存

编排器 SHALL 使用 `DraftBatch` 管理 CONFIRMING 态的草稿。编排器 SHALL 在 `_parseAndDeliver` 成功时从 `List<ParseResult>` 创建 `DraftBatch`。

CONFIRMING 状态下收到用户语音输入时，编排器 SHALL 按以下混合分流规则处理：

- **本地即时处理（Layer 1）**:
  - `confirm` → 确认所有 pending items（confirmAll），触发自动提交
  - `cancel` → 取消所有 items（cancelAll），清空 DraftBatch
  - `continueRecording` → 保存 confirmed items → 清空 → LISTENING
  - `exit` → 清空 DraftBatch，退出会话
  - `confirmItem(N)` → 确认第 N 笔（本地规则匹配「确认第X笔」模式）
  - `cancelItem(N)` → 取消第 N 笔（本地规则匹配「删掉第X笔」「取消第X笔」模式）
- **LLM 纠正处理（Layer 2）**:
  - `correction` / `newInput` → 立即 TTS 播报「好的，正在修改...」→ 调用 LLM batch correction 接口（3s 超时）或本地规则（离线）
  - LLM 返回 `corrections[]` + `intent == "correction"` + `confidence >= 0.7` → 逐条应用 updatedFields 到对应 item（注意：发送时排除 cancelled/confirmed items 并重编号，收到后映射回原始 index）
  - LLM 返回 `intent == "confirm"` → 执行全部确认
  - LLM 返回 `intent == "cancel"` → 执行全部取消
  - LLM 返回 `intent == "append"` → 将返回的交易字段构造为新 DraftTransaction 追加到 DraftBatch
  - LLM 返回 `intent == "unclear"` → TTS 提示重新表达
  - LLM 超时（>3s）→ 降级到本地规则纠正

编排器 SHALL NOT 在 CONFIRMING 状态下因纠正操作而清空 DraftBatch。

#### Scenario: 多笔全部确认
- **WHEN** 用户在 CONFIRMING 状态说「确认」，DraftBatch 含 4 笔 pending items
- **THEN** 编排器 SHALL confirmAll()，通过 VoiceTransactionService.saveBatch() 保存 4 笔，清空 DraftBatch

#### Scenario: 多笔定点纠正
- **WHEN** 用户在 CONFIRMING 状态说「第三笔改为支出」
- **THEN** 编排器 SHALL 发送 batch context + correctionText 到 LLM，收到 `corrections: [{index: 2, updatedFields: {type: "EXPENSE"}}]` 后更新 DraftBatch.items[2]

#### Scenario: 多笔逐条取消
- **WHEN** 用户说「删掉第二笔」
- **THEN** 编排器 SHALL cancelItem(1)，若仍有 pending items 则保持 CONFIRMING

#### Scenario: 多笔混合完成
- **WHEN** 用户先确认第1、3笔，再取消第2、4笔
- **THEN** 所有 item 非 pending 时，编排器 SHALL 自动保存 confirmed items (1, 3)，清空 DraftBatch

#### Scenario: 单笔兼容
- **WHEN** DraftBatch.items.length == 1
- **THEN** 所有操作行为 SHALL 与原有单笔行为完全一致（TTS 格式、确认/取消/纠正逻辑）

#### Scenario: 语音纠正通过 LLM 修改草稿
- **WHEN** 用户在 CONFIRMING 状态说「改为收入」，本地规则分类为 correction
- **THEN** 编排器 SHALL 立即 TTS 播报「好的，正在修改...」，将 `{currentBatch(pending items), "改为收入"}` 发送到 LLM 纠正接口（3s 超时），收到结果后更新 DraftBatch，通过 `Delegate.onDraftBatchUpdated` 通知 UI，TTS 播报修正后结果，状态 SHALL 保持 CONFIRMING

#### Scenario: LLM 二次判定为确认
- **WHEN** 用户说「嗯对就这样」，本地规则无法匹配确定性意图
- **THEN** 编排器 SHALL 将文本交给 LLM，LLM 返回 `intent: "confirm"`，编排器 SHALL 执行全部确认流程

#### Scenario: 纠正失败保持原结果
- **WHEN** LLM 返回 `intent: "unclear"` 或请求失败
- **THEN** 编排器 SHALL 保持 DraftBatch 不变，TTS 提示用户重新表达，状态 SHALL 保持 CONFIRMING

#### Scenario: LLM 纠正超时降级
- **WHEN** LLM 纠正请求超过 3 秒未返回
- **THEN** 编排器 SHALL 取消请求，降级到本地规则纠正，应用本地修正结果到 DraftBatch

#### Scenario: 取消当前记录
- **WHEN** 用户通过语音说「不要了」/「取消」或点击取消按钮
- **THEN** 系统 SHALL 清空 DraftBatch，状态 SHALL 回到 LISTENING

#### Scenario: 连续记账
- **WHEN** 用户确认保存后选择继续记账
- **THEN** 系统 SHALL 先保存 DraftBatch 中 confirmed items，清空 DraftBatch，再回到 LISTENING

#### Scenario: CONFIRMING 态追加新笔
- **WHEN** LLM 返回 `intent: "append"` 且 DraftBatch 笔数 < 10
- **THEN** 编排器 SHALL 创建新 DraftTransaction 追加到 DraftBatch 尾部，TTS 播报追加结果

#### Scenario: 追加超限拒绝
- **WHEN** LLM 返回 `intent: "append"` 但 DraftBatch 已有 10 笔
- **THEN** 编排器 SHALL 拒绝追加，TTS 播报「已达上限，请先确认当前交易」

### Requirement: 上下文提交与清空时机

编排器 SHALL 严格控制 `DraftBatch` 的生命周期。`DraftBatch` SHALL 仅在以下条件下被清空为 null：
1. 全部确认（或自动提交后）→ 保存后清空
2. 全部取消 → 直接清空
3. 混合状态完成 → 保存 confirmed → 清空
4. 退出/超时/dispose → 清空
5. 继续记账 → 保存 confirmed → 清空 → LISTENING

#### Scenario: 纠正不清空上下文
- **WHEN** 用户在 CONFIRMING 状态对 batch 中多笔进行纠正
- **THEN** 每次纠正 SHALL 仅更新对应 item，DraftBatch SHALL NOT 被清空

#### Scenario: 超时自动清空
- **WHEN** 会话因无操作超时
- **THEN** 系统 SHALL 清空 DraftBatch，释放所有资源

### Requirement: 纠正时 pending items 过滤与 index 重编号

编排器 SHALL 在发送 LLM 纠正请求时仅包含 pending 状态的 items，排除已取消和已确认的。发送前 SHALL 对 pending items 重新编号（从 0 开始），以便 LLM 返回的 index 直接对应 pending items 列表。收到 LLM response 后 SHALL 将重编号的 index 映射回 DraftBatch 中的原始 index。

#### Scenario: 纠正时排除 cancelled items
- **WHEN** DraftBatch 有 4 笔，index 1 已 cancelled，用户说「第二笔改成100」
- **THEN** 编排器 SHALL 仅发送 index 0、2、3 的 pending items（重编号为 0、1、2），LLM 返回 index 1 的修正 SHALL 映射回原始 index 2
