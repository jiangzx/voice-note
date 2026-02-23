## Purpose

定义语音交易纠正对话的系统行为，包括混合意图分流（本地规则 + LLM）、LLM 对话式纠正协议、离线降级策略和纠正应用反馈。

## Requirements

### Requirement: 混合意图分流

系统 SHALL 在 CONFIRMING 状态下对用户语音输入进行两层分流处理。

**Layer 1（本地规则，<1ms）**：对高确定性意图做即时分类。本地分类器 SHALL 按优先级检测 cancel > exit > continueRecording > confirm 四类确定性意图，以及 `confirmItem(N)` / `cancelItem(N)` 序号操作。匹配到任一确定性意图时 SHALL 立即执行对应操作，不经过 LLM。

**Layer 2（LLM 纠正，200-500ms）**：当 Layer 1 无法匹配确定性意图时（即 correction 或 newInput），系统 SHALL 将 `{currentBatch, correctionText}` 发送到服务端 LLM 纠正接口进行意图理解和字段修正。

#### Scenario: 确认意图由本地规则即时处理
- **WHEN** 用户在 CONFIRMING 状态说「确认」
- **THEN** 系统 SHALL 通过本地规则立即识别为 confirm 意图，SHALL NOT 调用 LLM

#### Scenario: 取消意图由本地规则即时处理
- **WHEN** 用户在 CONFIRMING 状态说「不要了」
- **THEN** 系统 SHALL 通过本地规则立即识别为 cancel 意图，SHALL NOT 调用 LLM

#### Scenario: 逐条确认由本地规则处理
- **WHEN** 用户在 CONFIRMING 状态说「确认第二笔」
- **THEN** 系统 SHALL 通过本地规则匹配序号模式，立即执行 confirmItem(1)，SHALL NOT 调用 LLM

#### Scenario: 逐条取消由本地规则处理
- **WHEN** 用户在 CONFIRMING 状态说「删掉第三笔」
- **THEN** 系统 SHALL 通过本地规则匹配序号模式，立即执行 cancelItem(2)，SHALL NOT 调用 LLM

#### Scenario: 纠正意图交由 LLM 处理
- **WHEN** 用户在 CONFIRMING 状态说「修改为收入」
- **THEN** 本地规则 SHALL 将其分类为需要 LLM 处理的纠正输入，系统 SHALL 调用服务端纠正接口

#### Scenario: 自然语言纠正交由 LLM 处理
- **WHEN** 用户在 CONFIRMING 状态说「那个应该是收入不是支出啊」
- **THEN** 本地规则 SHALL 无法匹配确定性意图，系统 SHALL 将其交给 LLM 进行意图理解

### Requirement: LLM 对话式纠正协议

系统 SHALL 通过服务端 `/api/v1/llm/correct-transaction` 接口进行 LLM 对话式纠正。请求 SHALL 包含当前 DraftBatch 中的 pending items（结构化上下文）和用户纠正文本。响应 SHALL 包含 `corrections[]`（字段级 delta 数组）、`intent`（二次意图分类）和 `confidence`。

**等待反馈**: 系统 SHALL 在发起 LLM 请求前立即通过 TTS 播报「好的，正在修改...」，填充用户等待时间。

**超时降级**: 系统 SHALL 为 LLM 纠正请求设置 **3 秒超时**。超时后 SHALL 降级到本地规则纠正（而非返回 unclear），并通过 TTS 播报本地纠正结果。

**confidence 阈值**: 当 LLM 返回 `confidence < 0.7` 时，系统 SHALL 忽略 `corrections`，将 `intent` 视为 `unclear`。

LLM 返回的 `intent` SHALL 被用作二次意图验证：
- `correction` + 非空 `corrections[]` + `confidence >= 0.7` → 逐条应用字段修正
- `confirm` → 执行全部确认
- `cancel` → 执行取消
- `append` → 将返回的交易字段追加为新 DraftTransaction
- `unclear` 或 `confidence < 0.7` → 保持原 DraftBatch，TTS 提示重新表达

#### Scenario: LLM 返回定点纠正
- **WHEN** 服务端收到 batch context（2 笔）和 correctionText「第一笔改成50」
- **THEN** LLM SHALL 返回 `{corrections: [{index: 0, updatedFields: {amount: 50.0}}], intent: "correction", confidence: 0.92}`

#### Scenario: LLM 返回描述词定位纠正
- **WHEN** 服务端收到 batch context（含一笔 category=红包）和 correctionText「红包那笔改为收入」
- **THEN** LLM SHALL 返回 `corrections` 中 index 指向 category=红包 的那笔，`updatedFields: {type: "INCOME"}`

#### Scenario: LLM 识别出确认意图
- **WHEN** 服务端收到 `correctionText: "嗯对就这样"`
- **THEN** LLM SHALL 返回 `{corrections: [], intent: "confirm", confidence: 0.85}`

#### Scenario: LLM 识别出追加意图
- **WHEN** 服务端收到 `correctionText: "还有一笔奶茶15"`
- **THEN** LLM SHALL 返回 `{corrections: [{index: -1, updatedFields: {amount: 15.0, category: "饮品", type: "EXPENSE", description: "奶茶"}}], intent: "append"}`

#### Scenario: LLM 无法理解纠正内容
- **WHEN** 服务端收到语义模糊的纠正文本
- **THEN** LLM SHALL 返回 `{corrections: [], intent: "unclear", confidence: 0.3}`

#### Scenario: LLM 返回多字段修正
- **WHEN** 用户说「改为收入100块」
- **THEN** LLM SHALL 返回 `{corrections: [{index: 0, updatedFields: {type: "INCOME", amount: 100.0}}], intent: "correction"}`

#### Scenario: LLM 处理期间播放 TTS 填充
- **WHEN** 系统发起 LLM 纠正请求
- **THEN** 系统 SHALL 在请求发出前立即通过 TTS 播报「好的，正在修改...」

#### Scenario: LLM 纠正超时降级
- **WHEN** LLM 纠正请求超过 3 秒未返回
- **THEN** 系统 SHALL 取消请求，降级到本地规则纠正，并通过 TTS 播报本地纠正结果

#### Scenario: 低 confidence 回退到 unclear
- **WHEN** LLM 返回 `confidence: 0.55`（低于 0.7 阈值）
- **THEN** 系统 SHALL 忽略 `corrections`，视为 `intent: "unclear"`，TTS 播报「没听清要改什么，请再说一次」

### Requirement: 离线降级纠正

系统 SHALL 在网络不可用时，将 LLM 纠正请求降级为本地规则纠正。本地规则 SHALL 支持以下纠正：
- 交易类型修正：检测「收入」→ INCOME / 「支出」→ EXPENSE
- 金额修正：从文本提取数字
- 分类修正：模糊匹配分类名

降级时 SHALL 通过 TTS 提示用户当前为离线模式，仅支持简单修正。

#### Scenario: 离线类型修正
- **WHEN** 网络不可用且用户说「改为收入」
- **THEN** 本地规则 SHALL 检测到「收入」关键词，将 type 修正为 INCOME

#### Scenario: 离线复杂纠正
- **WHEN** 网络不可用且用户说「那个应该是收入不是支出」
- **THEN** 本地规则 SHALL 检测到「收入」和「支出」关键词并修正类型。当前实现按先匹配到的类型应用（先检测收入再支出），与「最后出现」语义在部分句式下可能不同，以实现为准

### Requirement: 纠正应用与反馈

系统 SHALL 在纠正成功后通过 `Delegate.onDraftBatchUpdated` 通知 UI 更新确认卡片，并通过 TTS 播报修正后的结果。修正后状态 SHALL 保持 CONFIRMING，等待用户再次确认。

#### Scenario: 修正成功播报
- **WHEN** LLM 返回纠正结果且成功应用
- **THEN** 系统 SHALL 通过 TTS 播报更新后的结果（如「已将第1笔修改为收入60元，红包。还需要修改吗？」）

#### Scenario: 修正失败提示
- **WHEN** LLM 返回 `intent: "unclear"` 或本地规则无法提取有效修正
- **THEN** 系统 SHALL 保持 DraftBatch 不变，SHALL 通过 TTS 播报「没听清要改什么，请再说一次」

#### Scenario: 多次纠正累积
- **WHEN** 用户先说「改为收入」再说「金额改成100」
- **THEN** 两次修正 SHALL 分别独立应用到 DraftBatch 中对应 item，最终结果 SHALL 同时反映两次修正
