## ADDED Requirements

### Requirement: 批量交易识别

系统 SHALL 支持从单次语音输入中识别 1-N 笔交易。NLP 层 SHALL 返回 `List<ParseResult>` 而非单个 `ParseResult`。当输入仅包含单笔交易时，返回列表 SHALL 包含 1 个元素。

系统 SHALL 限制单次批量解析最大笔数为 10。超过 10 笔时 SHALL 截取前 10 笔并通过 TTS 提示用户。

#### Scenario: 多笔识别
- **WHEN** 用户说「吃饭花了60，洗脚花了60，抢红包抢了30，工资收到90」
- **THEN** 系统 SHALL 返回包含 4 个 ParseResult 的列表，每笔独立包含 amount、category、type 等字段

#### Scenario: 单笔识别（向后兼容）
- **WHEN** 用户说「午饭35块」
- **THEN** 系统 SHALL 返回包含 1 个 ParseResult 的列表

#### Scenario: 交易顺序保持
- **WHEN** 用户依次提及多笔交易
- **THEN** 返回列表中的交易顺序 SHALL 与用户提及顺序一致

#### Scenario: 离线降级为单笔
- **WHEN** 网络不可用时用户输入多笔交易
- **THEN** 系统 SHALL 仅通过本地 NLP 解析为单笔结果，TTS 提示「当前离线，仅支持单笔记账」

### Requirement: 草稿集合管理（DraftBatch）

编排器 SHALL 使用 `DraftBatch` 管理 CONFIRMING 态的多笔草稿。`DraftBatch` 包含有序的 `DraftTransaction` 列表，每笔持有独立的 `ParseResult` 和状态（pending/confirmed/cancelled）。

`DraftBatch` SHALL 为不可变数据模型：每次操作（updateItem/confirmItem/cancelItem 等）返回新实例。

#### Scenario: 创建 DraftBatch
- **WHEN** NLP 返回 `List<ParseResult>`
- **THEN** 编排器 SHALL 创建 `DraftBatch`，每个 ParseResult 对应一个 `DraftTransaction`（status: pending），index 从 0 开始

#### Scenario: 单笔草稿
- **WHEN** NLP 返回 1 个 ParseResult
- **THEN** `DraftBatch.items` SHALL 包含 1 个 `DraftTransaction`，后续处理逻辑与多笔完全一致

### Requirement: 逐条/整体确认

系统 SHALL 支持以下确认操作：

1. **全部确认**: 将所有 status==pending 的 item 标记为 confirmed
2. **逐条确认**: 将指定 index 的 item 标记为 confirmed

当所有 item 均为非 pending 状态（confirmed 或 cancelled）时，系统 SHALL 自动执行提交：保存所有 confirmed items 到数据库，清空 `DraftBatch`，状态回到 LISTENING。

#### Scenario: 全部确认
- **WHEN** 用户说「确认」或「全部确认」
- **THEN** 系统 SHALL 将所有 pending items 标记为 confirmed，触发自动提交

#### Scenario: 逐条确认
- **WHEN** 用户说「确认第一笔」
- **THEN** 系统 SHALL 将 index 0 的 item 标记为 confirmed，其余保持原状态

#### Scenario: 自动提交触发
- **WHEN** 最后一个 pending item 被确认或取消
- **THEN** 系统 SHALL 自动保存所有 confirmed items，清空 DraftBatch

### Requirement: 逐条/整体取消

系统 SHALL 支持以下取消操作：

1. **取消**: 将所有 item 标记为 cancelled，清空 DraftBatch
2. **逐条取消**: 将指定 index 的 item 标记为 cancelled

逐条取消后，若仍有 pending items，系统 SHALL 保持 CONFIRMING 状态并播报剩余笔数。

#### Scenario: 取消
- **WHEN** 用户说「取消」或「不要了」
- **THEN** 系统 SHALL 清空 DraftBatch，状态回到 LISTENING

#### Scenario: 逐条取消
- **WHEN** 用户说「删掉第二笔」
- **THEN** 系统 SHALL 将 index 1 的 item 标记为 cancelled，TTS 播报「已取消第2笔（{description}{amount}元）。剩余{N}笔待确认。」

#### Scenario: 取消最后一笔 pending 且有 confirmed
- **WHEN** 用户取消了最后一个 pending item，且存在 confirmed items
- **THEN** 系统 SHALL 自动保存 confirmed items，清空 DraftBatch

#### Scenario: 取消最后一笔且无 confirmed
- **WHEN** 用户取消了最后一个 pending item，且无 confirmed items
- **THEN** 系统 SHALL 清空 DraftBatch，TTS 播报「已取消。」

### Requirement: 定点纠正

系统 SHALL 支持通过序号或描述词定位特定笔进行纠正。定点纠正请求 SHALL 发送到 LLM 纠正接口，LLM 返回 `corrections[]` 指明修改的 item index 和 updatedFields。

#### Scenario: 序号定位纠正
- **WHEN** 用户说「第三笔改为支出」
- **THEN** 系统 SHALL 将 batch context + correctionText 发送到 LLM，LLM 返回 `corrections: [{index: 2, updatedFields: {type: "EXPENSE"}}]`

#### Scenario: 描述词定位纠正
- **WHEN** 用户说「红包那笔应该是收入」且 batch 中有一笔 category 为「红包」
- **THEN** LLM SHALL 根据 batch context 定位到该笔并返回对应 index 的修正

#### Scenario: 整体纠正
- **WHEN** 用户说「金额都加10块」
- **THEN** LLM SHALL 返回多个 correction，每笔各自增加 10

#### Scenario: 定位模糊
- **WHEN** 用户的纠正文本无法明确定位到某笔
- **THEN** LLM SHALL 返回 `intent: "unclear"`，系统 TTS 播报「不确定要修改哪笔，请说具体第几笔」

### Requirement: CONFIRMING 态追加新笔

系统 SHALL 支持在 CONFIRMING 态追加新交易到当前 DraftBatch。当 LLM 纠正接口返回 `intent: "append"` 时，系统 SHALL 将 LLM 返回的交易字段构造为新的 `DraftTransaction`（status: pending，index 接续 batch 最大 index + 1），追加到 DraftBatch 尾部。

DraftBatch 总笔数 SHALL NOT 超过 10。超限时 TTS 提示「已达上限，请先确认当前交易」。

#### Scenario: 追加新笔
- **WHEN** 用户在 CONFIRMING 态说「还有一笔奶茶15」
- **THEN** 系统 SHALL 将文本发送到 LLM 纠正接口，LLM 返回 `intent: "append"`，系统追加新笔到 DraftBatch

#### Scenario: 追加后播报
- **WHEN** 新笔追加成功
- **THEN** TTS SHALL 播报「已追加第{N}笔，{type}{amount}元，{category}。现在共{total}笔，请确认或修改。」

#### Scenario: 超限拒绝追加
- **WHEN** DraftBatch 已有 10 笔，用户尝试追加
- **THEN** 系统 SHALL 拒绝追加，TTS 播报「已达上限，请先确认当前交易」

### Requirement: 多笔 TTS 播报

系统 SHALL 根据 batch.size 自适应 TTS 播报格式：

- **单笔** (size == 1): 「记录{type}{amount}元，{category}，确认吗？」（与现有一致）
- **2-5 笔**: 「识别到{N}笔交易：第1笔，{type}{amount}元，{category}；...。请确认或修改。」
- **6-10 笔**: 「识别到{N}笔交易，共{totalExpense}元支出、{totalIncome}元收入。请查看详情后确认。」

#### Scenario: 定点修正播报
- **WHEN** 用户成功修正某笔
- **THEN** TTS SHALL 播报「已将第{N}笔修改为{type}{amount}元，{category}。还需要修改吗？」

#### Scenario: 保存成功播报
- **WHEN** batch 提交成功
- **THEN** TTS SHALL 播报「已保存{confirmedCount}笔交易。」

### Requirement: 批量交易保存

`VoiceTransactionService` SHALL 新增 `saveBatch(List<ParseResult>)` 方法。该方法 SHALL 在同一数据库事务中保存所有交易，任一笔保存失败 SHALL 回滚全部。

#### Scenario: 批量保存成功
- **WHEN** 编排器提交 4 笔 confirmed items
- **THEN** `saveBatch` SHALL 在单事务中保存 4 笔，返回 `List<TransactionEntity>`

#### Scenario: 批量保存失败回滚
- **WHEN** 4 笔中有 1 笔金额无效
- **THEN** `saveBatch` SHALL 回滚全部，抛出异常，编排器 SHALL 保持 DraftBatch 不变并 TTS 提示错误

### Requirement: 上下文清空规则

`DraftBatch` SHALL 仅在以下条件下被清空为 null：
1. 全部确认（或自动提交）→ 保存后清空
2. 取消 → 直接清空
3. 混合状态完成（所有 item 非 pending）→ 保存 confirmed → 清空
4. 退出/超时/dispose → 清空
5. 继续记账 → 保存当前 confirmed → 清空 → LISTENING

任何纠正操作（定点/整体）SHALL NOT 清空 DraftBatch。

#### Scenario: 纠正不清空上下文
- **WHEN** 用户对 batch 中某笔进行多次纠正
- **THEN** 每次纠正 SHALL 仅更新对应 item，DraftBatch SHALL NOT 被清空

#### Scenario: 超时清空
- **WHEN** 会话因无操作超时
- **THEN** 系统 SHALL 清空 DraftBatch，释放所有资源
