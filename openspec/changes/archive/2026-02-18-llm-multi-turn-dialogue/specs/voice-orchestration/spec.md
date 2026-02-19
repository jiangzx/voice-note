## MODIFIED Requirements

### Requirement: 交易确认与保存
编排器 SHALL 在 CONFIRMING 状态支持用户确认、取消或继续追加记账。确认后 SHALL 通过 VoiceTransactionService 将 ParseResult 映射为 TransactionEntity 并持久化到 SQLite。编排器 SHALL 在 CONFIRMING 状态采用混合路由策略：`confirm/cancel/exit/continue` 意图 SHALL 走本地快速路径（零延迟），`correction/newInput` 意图在联网时 SHALL 路由到 LLM 多轮对话端点，离线时 SHALL 降级到本地 `applyCorrection()` 处理。

#### Scenario: 确认保存
- **WHEN** 用户在 CONFIRMING 状态确认交易
- **THEN** 系统 SHALL 匹配分类（模糊匹配优先）、解析默认账户、生成 UUID，保存到 SQLite
- **THEN** 系统 SHALL 清空对话历史

#### Scenario: 连续记账
- **WHEN** 用户确认保存后选择继续记账
- **THEN** 系统 SHALL 先保存当前交易，再回到 LISTENING 状态等待下一笔
- **THEN** 系统 SHALL 清空对话历史

#### Scenario: 取消当前记录
- **WHEN** 用户通过语音说"不要了"/"取消"或点击取消按钮
- **THEN** 系统 SHALL 丢弃当前解析结果，状态 SHALL 回到 LISTENING
- **THEN** 系统 SHALL 清空对话历史

#### Scenario: 退出时清空对话历史
- **WHEN** 用户在 CONFIRMING 状态说退出指令
- **THEN** 系统 SHALL 清空对话历史，状态 SHALL 变为 IDLE

#### Scenario: 在线纠正走 LLM 对话
- **WHEN** 用户在 CONFIRMING 状态说"不对，应该是收入"且设备在线
- **THEN** 编排器 SHALL 将文本添加到对话历史，携带完整对话历史和当前交易调用 ConversationRepository
- **THEN** 编排器 SHALL 根据 LLM 返回的 action 执行对应操作

#### Scenario: LLM 返回 correct action
- **WHEN** LLM 对话端点返回 `{action: "correct", transaction: {amount:60, type:"INCOME", category:"红包"}}`
- **THEN** 编排器 SHALL 使用返回的 transaction 更新 lastParseResult 对应字段，通过 Delegate.onParseResultUpdated 通知 UI
- **THEN** 编排器 SHALL 将 assistant 响应添加到对话历史

#### Scenario: LLM 返回 parse action
- **WHEN** LLM 对话端点返回 `{action: "parse", transaction: {...新交易}}`
- **THEN** 编排器 SHALL 清空对话历史，将返回的 transaction 作为新交易处理（等同于新的 _parseAndDeliver 结果）

#### Scenario: LLM 返回 clarify action
- **WHEN** LLM 对话端点返回 `{action: "clarify", message: "请问您想修改哪个部分？"}`
- **THEN** 编排器 SHALL 通过 TTS 播报 message 内容，状态保持 CONFIRMING 继续等待用户输入
- **THEN** 编排器 SHALL 将 assistant 响应添加到对话历史

#### Scenario: LLM 返回 query action
- **WHEN** LLM 对话端点返回 `{action: "query", message: "这个月花了多少"}`
- **THEN** 编排器 SHALL 通过 TTS 播报"查询功能即将上线"提示，状态保持 CONFIRMING

#### Scenario: 离线纠正降级到本地
- **WHEN** 用户在 CONFIRMING 状态说"改成收入"且设备离线
- **THEN** 编排器 SHALL 使用 VoiceCorrectionHandler.applyCorrection 本地处理纠正
- **THEN** 若本地纠正成功，SHALL 通过 Delegate.onParseResultUpdated 通知 UI

#### Scenario: LLM 调用失败降级
- **WHEN** LLM 对话端点调用失败（网络异常或超时）
- **THEN** 编排器 SHALL 降级到本地 applyCorrection 处理
- **THEN** 若本地也无法处理，SHALL 通过 Delegate.onInterimText 显示原文
