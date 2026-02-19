## Why

当前语音记账系统存在两个核心缺陷：一是 CONFIRMING 态上下文丢失——用户语音纠正时系统将纠正语句当作全新交易处理，而纯规则引擎方案无法穷举中文纠正表达的多样性；二是仅支持单笔交易识别——用户说「吃饭60、打车30、红包收了50」时 NLP 只解析出一条交易（研究显示约 52% 的真实语音输入包含多意图）。两个问题在架构上高度耦合：批量交易的草稿管理（`DraftBatch`）是单笔上下文保持（`_stagedResult`）的泛化，批量纠正接口是单笔纠正接口的扩展。因此合并为一次变更，直接构建最终架构，避免中间产物。

## What Changes

- 新增「LLM 对话式纠正」能力：CONFIRMING 态采用混合架构——本地规则处理确定性意图（确认/取消/退出/继续），LLM 处理纠正和模糊输入
- 服务端新增 `correct-transaction` 接口，原生支持 batch context（单笔作为 batch.size==1 的特例）
- LLM 解析从「单笔→单对象」升级为「一段话→交易数组」，`parse-transaction` 响应统一返回 `transactions[]`
- 编排器引入 `DraftBatch`（草稿集合）替代原有无状态模型，支持逐条/整体的确认、取消、定点纠正、追加新笔
- 本地纠正规则增强：扩展关键词覆盖 + 交易类型修正 + 序号匹配模式，作为离线降级方案
- TTS 播报模板升级：支持纠正等待填充、多笔摘要播报、定点修正反馈
- 确认卡片 UI 升级：多笔列表展示、滑动手势操作、状态可视化动画
- **BREAKING**: `parse-transaction` 响应格式从单对象变为数组，直接升级不做 v1 兼容

## Capabilities

### New Capabilities
- `voice-batch-transaction`: 定义多笔交易的识别、DraftBatch 草稿集合管理、批量/逐条确认取消、定点纠正、追加新笔的完整行为
- `voice-correction-dialogue`: 定义 CONFIRMING 状态下混合分流策略、LLM 对话式纠正协议、离线降级规则、confidence 阈值、TTS 反馈

### Modified Capabilities
- `voice-orchestration`: `_handleConfirmingSpeech` 重构为混合分流，引入 `DraftBatch` 生命周期管理，定义上下文提交/清空的严格时机
- `ai-gateway-llm`: `parse-transaction` 支持返回交易数组，新增 `correct-transaction` 接口（原生 batch-aware）

## Impact

- **Server API** (`LlmController`, `LlmService`): `parse-transaction` 响应变为数组，新增 `correct-transaction` 端点（batch-aware）
- **Server Prompts**: `transaction-parse.txt` 升级为多笔解析，新增 `correction-dialogue.txt`（batch few-shot）
- **API Contract** (`voice-note-api.yaml`): parse 响应 schema 变为数组，新增 correction 接口 schema
- **Client 数据模型**: 新增 `DraftBatch`、`DraftTransaction`
- **Client 编排器** (`voice_orchestrator.dart`): 引入 `DraftBatch`，重构 `_handleConfirmingSpeech` 为混合分流
- **Client NLP** (`nlp_orchestrator.dart`): `parse` 返回 `List<ParseResult>`，新增 `correct` 方法
- **Client 网络层** (`llm_repository.dart`): parseTransaction 返回数组，新增 correctTransaction（batch）
- **Client 纠正处理器** (`voice_correction_handler.dart`): 扩展为混合分流器，新增序号匹配模式
- **Client UI**: 新增 `BatchConfirmationCard` widget，`VoiceSessionState` 升级为 `draftBatch`
- **TTS 模板** (`tts_templates.dart`): 新增纠正填充 + 多笔播报 + 定点修正反馈模板
- **测试**: 全栈新增批量交易 + 纠正对话场景测试
