## Context

### 当前系统架构

```
用户语音 → ASR → NLP (local + LLM) → ParseResult(单笔) → CONFIRMING(无状态) → 用户回复 → ???
```

当前 NLP 链路为单轮无状态：`NlpOrchestrator.parse(text)` 返回单个 `ParseResult`，不携带对话历史。`VoiceOrchestrator` 在 CONFIRMING 态没有草稿引用——收到用户回复后，`_handleConfirmingSpeech` 对纠正/新输入分支的处理存在根本缺陷。

### 问题根因

**根因 1：VoiceCorrectionHandler 意图分类覆盖不足 + correction 分支为死代码**

`_correctionPrefixes` 仅有 `[不对, 改一下, 改成, 错了]`，不覆盖 `修改为`、`应该是`、`那个搞错了` 等常见表达。更关键的是 `_handleConfirmingSpeech` 的 `correction` case 仅调用 `_delegate.onInterimText(text)`，`VoiceCorrectionHandler.applyCorrection()` 从未被调用。`newInput` 分支直接调用 `_parseAndDeliver(text)` 丢弃上下文。

**根因 2：LLM Prompt 要求返回单对象**

`transaction-parse.txt` 明确要求 `Return a JSON object with the following fields: {...}`，当输入包含多笔交易时 LLM 被迫合并或选择其一，导致数据丢失。

**根因 3：Client 数据模型缺少集合概念**

`ParseResult` 是单体类，`NlpOrchestrator.parse()` 返回 `ParseResult?`（单笔），整个下游管线围绕单笔设计。无法对多笔草稿进行独立的确认、取消或定点纠正。

### 架构融合点

上述问题在架构上高度耦合：修复纠正上下文需要引入草稿引用（`_stagedResult`），而支持多笔交易需要将草稿从单笔泛化为集合（`DraftBatch`）。批量纠正接口是单笔纠正接口的超集（`batch.size == 1` 等价于单笔）。因此合并为一次变更，直接构建最终形态。

### 行业实践参考

1. **Slot-filling 对话模式**: 将交易字段视为待填充 slot，纠正是对已填 slot 的修改操作
2. **Multi-Intent NLU**: Amazon 数据集约 52% 语音输入含多意图，主流 NLU 已支持多 intent+slot 提取
3. **Unified Single/Batch Model**: 单笔视为 batch.size==1，消除代码路径分叉
4. **结构化上下文 > 原始对话历史**: 发送 `{currentBatch, correctionText}` 而非原始 messages 数组

## Goals / Non-Goals

**Goals:**

1. CONFIRMING 态的用户语音回复被准确理解为对当前交易的操作（纠正/确认/取消）
2. 利用 LLM 多轮对话能力理解多样化的纠正表达，不依赖关键词穷举
3. 支持一段语音输入中识别并返回多笔交易（1-N 笔）
4. 统一单笔和多笔的处理模型（DraftBatch，size == 1 视为单笔）
5. CONFIRMING 态支持逐条播报、定点纠正、逐条/整体确认/取消
6. 本地规则引擎处理高确定性意图（<1ms），LLM 处理模糊意图（200-500ms）
7. 离线降级：纠正走增强本地规则，多笔降级为单笔
8. 服务端 LLM 调用保持无状态（不在 Server 维护对话 session）

**Non-Goals:**

- 跨 batch 的交易关联（每个 batch 独立）
- 超过 10 笔的批量处理
- 客户端本地运行 LLM 模型 / 本地多笔分割
- Server 维护对话 session state
- 通用对话能力（仅限交易场景）
- 自动合并重复交易

## Core Concepts

### DraftBatch（草稿集合）

从语音输入中解析出的多笔交易草稿的有序集合。每笔草稿独立持有 `ParseResult` 和状态。单笔交易是 `DraftBatch.size == 1` 的特例。

```dart
class DraftBatch {
  final List<DraftTransaction> items;
  final DateTime createdAt;

  int get pendingCount => items.where((t) => t.status == DraftStatus.pending).length;
  bool get allResolved => items.every((t) => t.status != DraftStatus.pending);

  DraftBatch updateItem(int index, ParseResult result) { ... }
  DraftBatch confirmItem(int index) { ... }
  DraftBatch cancelItem(int index) { ... }
  DraftBatch confirmAll() { ... }
  DraftBatch cancelAll() { ... }
  List<DraftTransaction> get pendingItems => ...;
}

class DraftTransaction {
  final int index;           // 0-based, stable identifier
  final ParseResult result;
  final DraftStatus status;  // pending | confirmed | cancelled
}

enum DraftStatus { pending, confirmed, cancelled }
```

### Targeted Correction（定点纠正）

用户通过序号或描述词指定要修正的笔数。LLM 根据 batch context 理解用户指向，返回 `corrections[]` 形式的修正指令。

### Atomic Commit

当所有 item 非 pending（均为 confirmed 或 cancelled）时，自动提交所有 confirmed items，无需最终确认步骤。

## Decisions

### Decision 1: 混合分流架构（Local Rules + LLM）

**选择**: 两层分流策略

```
用户回复
  ↓
Layer 1: Local Intent Classifier (规则引擎, <1ms)
  ├─ confirm → 确认（全部/逐条）
  ├─ cancel → 取消（全部/逐条）
  ├─ exit → 退出
  ├─ continueRecording → 继续
  └─ correction / newInput → Layer 2
       ↓
Layer 2: LLM Correction Service (在线, 200-500ms)
  ├─ 发送 {currentBatch, correctionText} 到 Server
  ├─ LLM 理解意图并返回 {corrections[], intent}
  └─ 离线降级 → Local applyCorrection (扩展规则)
```

**替代方案**:
- A) 全部走 LLM → 延迟高，离线不可用，成本浪费在确认/取消上
- B) 全部走规则引擎 → 无法覆盖中文纠正表达多样性
- C) 本地小模型 → Flutter 生态无成熟本地 NLU 方案

**理由**: 80% 的交互是确认/取消等确定性意图，20% 是纠正。混合方案在延迟、成本和智能度之间取得最优平衡。

### Decision 2: 统一 Batch 模型（单笔 = batch.size == 1）

**选择**: 所有交易处理统一为 batch 模型。LLM 始终返回 `transactions[]` 数组。编排器始终持有 `DraftBatch`。

**替代方案**:
- A) 单笔/多笔分开处理（if/else 分叉）→ 代码路径倍增，维护成本高
- B) 先做单笔草稿再泛化 → 产生一次性中间代码

**理由**: 统一模型消除条件分叉，所有 confirm/cancel/correction 逻辑只写一份。TTS 播报根据 batch.size 自适应。跳过 `_stagedResult` 中间态，直接构建最终架构。

### Decision 3: parse-transaction 响应直接升级为数组

**选择**: 修改 `transaction-parse.txt` Prompt，LLM 返回 `{"transactions": [...]}` 格式。Server 新增 `TransactionBatchParseResponse`。直接升级，不做 v1 兼容。

**Server 响应格式**:
```kotlin
data class TransactionBatchParseResponse(
    val transactions: List<TransactionParseResponse>,
    val model: String = ""
)
```

**替代方案**:
- A) v2 新端点 → 两个端点维护成本高
- B) Header-based 版本切换 → Server 复杂度增加
- C) 保持单对象，客户端多次调用 → 延迟线性增长

**理由**: 当前仅有一个客户端（Flutter app），无第三方 API 消费者。同 mono-repo 同步发布。

### Decision 4: correct-transaction 接口原生 batch-aware

**选择**: 新增 `POST /api/v1/llm/correct-transaction`，原生支持 batch context（单笔作为特例）。

**Request**:
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

**Response**:
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

**兼容设计**:
- `currentBatch` 仅 1 个元素时等价于单笔纠正
- `intent` 枚举：`correction`、`confirm`、`cancel`、`unclear`、`append`
- 客户端发送 `currentBatch` 时 SHALL 仅包含 pending items，排除已取消/已确认的，发送前重编号

**替代方案**:
- A) 先做单笔再扩展 batch → 接口变更两次，prompt 改两次
- B) 复用 parse-transaction → 职责混杂，prompt 设计复杂

**理由**: 专用接口有专用 prompt，LLM 被明确指导纠正任务。直接 batch-aware 避免二次改造。

### Decision 5: 结构化上下文 + Few-shot Prompt

**选择**: 客户端发送 `{currentBatch, correctionText}`，Server 在 Prompt 模板中组装为结构化上下文 + few-shot 示例

**Server Prompt 模板** (`correction-dialogue.txt`):
```
You are a bookkeeping correction assistant for "随口记".
The user has pending transactions that need correction.

Current transactions:
{batchContext}

The user said: "{correctionText}"

Determine what changes are needed. Return ONLY a JSON:
{
  "corrections": [
    {"index": N, "updatedFields": {"fieldName": "newValue"}}
  ],
  "intent": "correction" | "confirm" | "cancel" | "unclear" | "append",
  "confidence": 0.0 to 1.0
}

Rules:
1. Index refers to the item index in the batch (0-based).
2. 用户说「第N笔」对应 index N-1.
3. Only include fields that need changing in updatedFields.
4. For append intent, return the new transaction fields in corrections[0].updatedFields.
...

Examples:
[3-5 batch few-shot examples covering: 序号定位、描述词定位、多笔修正、确认、取消、追加]
```

**替代方案**:
- A) Zero-shot → LLM 对 JSON 格式和 intent 理解不准确
- B) 客户端拼接 messages 数组 → token 浪费
- C) 只发 correctionText 不发 context → LLM 无法理解用户意图

**理由**: Few-shot 让 LLM 快速理解输出格式。结构化上下文精简（<600 tokens）。Server 保持无状态。

### Decision 6: DraftBatch 生命周期

**选择**: `VoiceOrchestrator` 新增 `DraftBatch? _draftBatch`

**生命周期**:
```
LISTENING → ASR finalText → NLP parse → DraftBatch 创建 → CONFIRMING
                                                            ↓
                                                    纠正: updateItem()
                                                    确认: confirmItem() / confirmAll()
                                                    取消: cancelItem() / cancelAll()
                                                    追加: append new item
                                                            ↓
                                                    all non-pending?
                                                    ├─ YES → saveBatch(confirmed) → 清空 → LISTENING
                                                    └─ NO → 继续 CONFIRMING
```

**清空的唯一合法条件**:
1. 全部确认 / 混合状态完成 → 保存后清空
2. 取消 → 直接清空
3. 继续记账 → 保存 confirmed → 清空
4. 退出/超时/dispose → 清空

**SHALL NOT 清空的场景**: 纠正、逐条取消（除非最后一个 pending 也被处理）

### Decision 7: LLM 超时 3 秒降级 + TTS 等待填充

**选择**: LLM 纠正请求设置 3 秒超时。发起前立即播放 TTS「好的，正在修改...」。超时降级到本地规则纠正。

**理由**: 3 秒是语音交互感知等待阈值。TTS 填充消除"卡住"感。降级覆盖 80% 常见纠正。

### Decision 8: confidence < 0.7 回退 + 轻校验

**选择**:
- LLM 返回 `confidence < 0.7` → 忽略 `updatedFields`，视为 `intent: "unclear"`
- 轻校验仅检查 JSON 格式 + `intent` 枚举 + `index` 范围，不对字段值做严格校验

**理由**: 0.7 阈值提供适度保守性。Prompt few-shot 已约束输出格式，极端异常由 JSON 解析层自然捕获。

### Decision 9: TTS 多笔播报策略

**选择**: 根据 batch.size 自适应

- **单笔** (size == 1): 保持现有「记录支出60元，餐饮，确认吗？」
- **2-5 笔**: 逐条播报「识别到{N}笔交易：第1笔，...。请确认或修改。」
- **6-10 笔**: 摘要播报「识别到{N}笔交易，共{expense}元支出、{income}元收入。请查看详情后确认。」
- **定点修正后**: 「已将第{N}笔修改为...。还需要修改吗？」

**理由**: 逐条播报超 5 笔时过长。摘要模式让用户通过 UI 查看详情。

### Decision 10: 本地 NLP 离线降级策略

**选择**:
- 多笔识别必须依赖 LLM，离线时降级为单笔本地解析
- 纠正离线时使用增强本地规则（扩展关键词 + 类型修正 + 金额修正 + 分类模糊匹配）
- TTS 明确提示离线状态

**理由**: 多意图分割是复杂 NLU 问题，本地规则无法可靠完成。纠正的本地规则可覆盖高频场景。

### Decision 11: CONFIRMING 态追加新笔

**选择**: LLM 纠正接口 `intent` 新增 `append` 枚举值。收到 `append` 时追加新 DraftTransaction 到 batch 尾部。DraftBatch 上限 10 笔。

**替代方案**:
- A) 视为新 batch → 用户需两次确认，体验碎片化
- B) 不支持追加 → 用户必须先确认/取消当前 batch

**理由**: 追加到当前 batch 最符合用户心智模型（「我在报告消费，刚才漏了一笔」）。

### Decision 12: 确认卡片 UI 支持多笔列表

**选择**: 单笔保持现有卡片；多笔使用可滚动列表卡片，支持 swipe 手势（左滑取消/右滑确认）、状态可视化（pending/confirmed/cancelled）、全部确认/取消按钮。

**理由**: 语音是输入通道，视觉是审核通道。多笔场景下 UI 列表比 TTS 逐条播报更高效。

## Interaction Examples

### Example 1: 多笔识别与全部确认

```
User: "吃饭花了60，洗脚花了60，抢红包抢了30，工资收到90"
TTS: "识别到4笔交易：第1笔，支出60元，餐饮；第2笔，支出60元，洗浴；第3笔，收入30元，红包；第4笔，收入90元，工资。请确认或修改。"
UI: [4行列表，底部"全部确认""取消"]
User: "确认"
TTS: "已保存4笔交易。"
```

### Example 2: 定点纠正

```
User: "吃饭花了60，打车30"
TTS: "识别到2笔交易：...请确认或修改。"
User: "第一笔改成50"
TTS: "好的，正在修改...已将第1笔金额修改为50元。还需要修改吗？"
User: "确认"
TTS: "已保存2笔交易。"
```

### Example 3: 单笔纠正（向后兼容）

```
User: "红包收了60"
TTS: "识别到收入60元，红包，确认吗？"
User: "应该是支出不是收入"
TTS: "好的，正在修改...已修改为支出60元，红包，确认吗？"
User: "确认"
TTS: "记好了，还有吗？"
```

### Example 4: 追加新笔

```
User: "吃饭60、打车30"
TTS: "识别到2笔交易...请确认或修改。"
User: "还有一笔奶茶15"
TTS: "已追加第3笔，支出15元，饮品。现在共3笔，请确认或修改。"
User: "确认"
```

## Data Model

### Server 新增 DTO

```kotlin
// Batch parse response
data class TransactionBatchParseResponse(
    val transactions: List<TransactionParseResponse>,
    val model: String = ""
)

// Correction request (native batch-aware)
data class TransactionCorrectionRequest(
    val currentBatch: List<BatchItem>,
    val correctionText: String,
    val context: ParseContext? = null
)

data class BatchItem(
    val index: Int,
    val amount: Double?,
    val category: String?,
    val type: String?,
    val description: String?,
    val date: String?
)

// Correction response
data class TransactionCorrectionResponse(
    val corrections: List<CorrectionItem>,
    val intent: CorrectionIntent,
    val confidence: Double = 0.0,
    val model: String = ""
)

data class CorrectionItem(
    val index: Int,
    val updatedFields: Map<String, Any?>
)

enum class CorrectionIntent {
    CORRECTION, CONFIRM, CANCEL, UNCLEAR, APPEND
}
```

### Client DraftBatch

```dart
DraftBatch(
  items: [
    DraftTransaction(index: 0, result: ParseResult(...), status: DraftStatus.pending),
    DraftTransaction(index: 1, result: ParseResult(...), status: DraftStatus.pending),
  ],
  createdAt: DateTime.now(),
)
```

## Risks / Trade-offs

- **[Risk] LLM 纠正延迟 200-500ms 影响语音交互流畅度** → Mitigation: 请求前 TTS「好的，正在修改...」填充等待；3 秒超时硬上限
- **[Risk] LLM 返回不可解析的 JSON** → Mitigation: Server 端 `extractJson` 容错；客户端轻校验，失败时保持原 DraftBatch 不变
- **[Risk] LLM 误判意图** → Mitigation: Prompt few-shot + confidence < 0.7 回退 unclear
- **[Risk] LLM 分割错误** → Mitigation: Prompt 分割示例指导；低 confidence 笔标记提醒
- **[Risk] 多笔 TTS 播报过长（>10s）** → Mitigation: 超 5 笔改摘要播报
- **[Risk] parse-transaction 响应 breaking change** → Mitigation: 同 mono-repo 同步升级，无第三方消费者
- **[Risk] 用户混淆序号** → Mitigation: TTS/UI 用 1-based 序号；Prompt 约定第N笔 = index N-1
- **[Risk] 离线时多笔能力完全不可用** → Mitigation: 降级单笔 + TTS 明确提示
- **[Risk] 纠正时 cancelled items 导致序号混淆** → Mitigation: 客户端维护 index 映射表，TTS/UI 使用原始 1-based 序号
- **[Risk] DraftBatch 无限增长** → Mitigation: 限制 10 笔上限
- **[Risk] 变更范围大（合并两个 change）** → Mitigation: 按技术层分阶段实施，每层独立可测；单笔作为 batch.size==1 的特例提供回归保护
