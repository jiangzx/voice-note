## MODIFIED Requirements

### Requirement: 交易文本解析
系统 SHALL 提供 REST 端点 `POST /api/v1/llm/parse-transaction`，接收自然语言文本及可选上下文，调用 LLM 返回结构化交易数据。响应 SHALL 包含 `transactions` 数组（`List<TransactionParseResponse>`），每个元素包含：amount、currency、date、category、description、type、account、confidence。单笔输入 SHALL 返回包含 1 个元素的数组。多笔输入 SHALL 按用户提及顺序返回。无法确定的字段 SHALL 返回 null。

#### Scenario: 多笔解析
- **WHEN** 客户端发送 `{text: "吃饭花了60，抢红包抢了30"}`
- **THEN** 系统 SHALL 返回 200，`transactions` 包含 2 个元素，第 1 个为支出60餐饮，第 2 个为收入30红包

#### Scenario: 单笔解析（数组格式）
- **WHEN** 客户端发送 `{text: "午饭35块"}`
- **THEN** 系统 SHALL 返回 200，`transactions` 包含 1 个元素

#### Scenario: 解析顺序保持
- **WHEN** 请求文本包含多笔交易
- **THEN** `transactions` 数组中元素顺序 SHALL 与输入文本中的提及顺序一致

#### Scenario: 上下文增强解析
- **WHEN** 客户端发送 `{text: "买了本书", context: {customCategories: ["学习资料"]}}`
- **THEN** 系统 SHALL 优先使用用户自定义分类"学习资料"而非默认分类

#### Scenario: 请求体校验失败
- **WHEN** 客户端发送 `{text: ""}`（空文本）
- **THEN** 系统 SHALL 返回 HTTP 400，响应体 SHALL 包含 `{error: "validation_failed"}`

### Requirement: 批量解析 Prompt 模板

`transaction-parse.txt` SHALL 升级为指导 LLM 返回交易数组。Prompt SHALL 包含：
1. 明确指令：「输入可能包含多笔交易，请每笔独立解析并按顺序返回」
2. 输出格式约束：`{"transactions": [...]}`
3. **3-5 个 few-shot 示例**，覆盖：单笔、双笔、多笔（含收入和支出混合）、共享字段继承
4. 分割规则：以逗号、顿号、句号等标点或「然后」「还有」「另外」等连接词作为交易边界

#### Scenario: 分割歧义处理
- **WHEN** 输入为「60块钱的火锅打车回来30」（语义连贯但实为 2 笔）
- **THEN** Prompt 中的 few-shot 示例 SHALL 指导 LLM 按消费场景分割为 2 笔

#### Scenario: 共享字段继承
- **WHEN** 输入为「今天吃饭60、奶茶15」（「今天」为共享日期）
- **THEN** LLM SHALL 将 date 应用到两笔交易

## ADDED Requirements

### Requirement: 交易纠正接口

系统 SHALL 提供 `POST /api/v1/llm/correct-transaction` 接口用于 LLM 对话式交易纠正。接口 SHALL 原生支持 batch context：请求包含 `currentBatch`（交易数组 + index）和 `correctionText`。单笔纠正为 `currentBatch` 仅含 1 个元素的特例。

**Request Schema**:
```json
{
  "currentBatch": [
    {"index": 0, "amount": 60, "category": "餐饮", "type": "EXPENSE", "description": "吃饭"},
    {"index": 1, "amount": 30, "category": "交通", "type": "EXPENSE", "description": "打车"}
  ],
  "correctionText": "第一笔改成50",
  "context": {
    "recentCategories": ["餐饮", "交通"],
    "customCategories": []
  }
}
```

**Response Schema**:
```json
{
  "corrections": [
    {"index": 0, "updatedFields": {"amount": 50.0}}
  ],
  "intent": "correction",
  "confidence": 0.92,
  "model": "qwen-turbo"
}
```

接口 SHALL 复用现有的 API Key 认证和 rate-limit 机制。`intent` 字段 SHALL 为枚举值之一：`correction`、`confirm`、`cancel`、`unclear`、`append`。`corrections[].updatedFields` SHALL 仅包含需要修改的字段（delta）。

#### Scenario: 定点纠正
- **WHEN** 请求包含 2 笔 batch 和 correctionText「第一笔改成50」
- **THEN** 接口 SHALL 返回 `corrections: [{index: 0, updatedFields: {amount: 50.0}}]`

#### Scenario: 描述词定位
- **WHEN** 请求包含 batch（含一笔 category=红包）和 correctionText「红包那笔改为收入」
- **THEN** 接口 SHALL 返回 `corrections` 中 index 指向 category=红包 的那笔

#### Scenario: 多笔同时修正
- **WHEN** correctionText 为「金额都改成100」
- **THEN** 接口 SHALL 返回 `corrections` 包含所有 item 的金额修正

#### Scenario: 单笔 batch 兼容
- **WHEN** `currentBatch` 仅含 1 个元素
- **THEN** 行为 SHALL 等价于单笔纠正

#### Scenario: LLM 判定为确认
- **WHEN** correctionText 为「嗯对就这样」
- **THEN** 接口 SHALL 返回 `{corrections: [], intent: "confirm"}`

#### Scenario: LLM 判定为追加
- **WHEN** correctionText 为「还有一笔奶茶15」
- **THEN** 接口 SHALL 返回 `{corrections: [{index: -1, updatedFields: {amount: 15.0, category: "饮品", type: "EXPENSE"}}], intent: "append"}`

#### Scenario: LLM 无法理解
- **WHEN** correctionText 语义模糊
- **THEN** 接口 SHALL 返回 `{corrections: [], intent: "unclear", confidence: <0.5}`

#### Scenario: LLM 调用失败
- **WHEN** DashScope API 返回错误或超时
- **THEN** 接口 SHALL 返回 HTTP 502，客户端 SHALL 降级到本地规则纠正

### Requirement: 纠正 Prompt 模板（Batch-aware Few-shot）

系统 SHALL 使用专用 Prompt 模板（`correction-dialogue.txt`）指导 LLM 进行 batch-aware 纠正。Prompt SHALL 包含：
1. 当前 batch 的完整列表（每笔含 index、字段值）
2. 序号映射规则：用户「第N笔」对应 index N-1
3. 描述词匹配指引：LLM 应根据 category/description 匹配用户描述
4. 明确的字段映射规则（收入→INCOME、支出→EXPENSE）
5. **3-5 个 few-shot 示例**，覆盖：序号定位、描述词定位、多笔同时修正、确认、取消、追加

#### Scenario: Prompt 包含 batch context
- **WHEN** Server 处理 batch correction 请求
- **THEN** Prompt SHALL 列出所有 batch items 及其 index，让 LLM 理解每笔内容

#### Scenario: Prompt 约束输出格式
- **WHEN** LLM 生成回复
- **THEN** Prompt SHALL 要求 LLM 仅返回 JSON 对象，不包含解释或 markdown 标记

### Requirement: 响应校验（轻校验）

系统 SHALL 对批量解析和批量纠正的 LLM 返回值进行轻校验：
1. JSON 格式合法性
2. `transactions` / `corrections` 为数组
3. 纠正响应中 `index` 值在 batch 范围内
4. `intent` 枚举值合法（`correction`/`confirm`/`cancel`/`unclear`/`append`）

系统 SHALL NOT 对字段值做严格类型校验。

#### Scenario: JSON 不可解析
- **WHEN** LLM 返回非法 JSON
- **THEN** Server SHALL 返回 502，客户端 SHALL 降级到本地规则纠正

#### Scenario: intent 值非法
- **WHEN** LLM 返回的 intent 不在枚举范围内
- **THEN** Server SHALL 将 intent 默认为 `unclear`，返回 200

#### Scenario: index 越界
- **WHEN** LLM 返回的 correction 中 index 超出 batch 范围
- **THEN** Server SHALL 过滤掉该 correction，仅返回合法的修正项

### Requirement: confidence 阈值策略

客户端 SHALL 对 LLM 返回的 `confidence` 值应用 0.7 阈值。当 `confidence < 0.7` 时，客户端 SHALL 忽略 `corrections`，将 `intent` 视为 `unclear`，通过 TTS 提示用户重新表达。

#### Scenario: 低 confidence 回退
- **WHEN** LLM 返回 `{corrections: [{index: 0, updatedFields: {type: "INCOME"}}], intent: "correction", confidence: 0.55}`
- **THEN** 客户端 SHALL 忽略 corrections，视为 unclear，TTS 播报「没听清要改什么，请再说一次」
