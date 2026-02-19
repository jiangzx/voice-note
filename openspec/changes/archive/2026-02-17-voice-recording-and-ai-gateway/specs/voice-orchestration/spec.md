## ADDED Requirements

### Requirement: 语音管线编排
系统 SHALL 提供 VoiceOrchestrator 组件，统一编排 AudioCapture → VAD → ASR → NLP 的完整语音管线。编排器 SHALL 通过 VoiceOrchestratorDelegate 接口与 UI 层解耦。编排器 SHALL 管理四态状态机（IDLE → LISTENING → RECOGNIZING → CONFIRMING）的流转。

#### Scenario: 自动模式完整流程
- **WHEN** 编排器以自动模式启动监听
- **THEN** 系统 SHALL 启动 AudioCapture 和 VAD，VAD 检测到人声时 SHALL 自动连接 ASR，ASR 返回结果后 SHALL 交给 NLP 解析，解析完成 SHALL 通过 Delegate.onFinalText 回调通知 UI

#### Scenario: 按住说话模式
- **WHEN** 编排器以 pushToTalk 模式启动
- **THEN** 系统 SHALL 在用户按下时开始录音和 ASR，松开时停止录音

#### Scenario: 键盘输入模式
- **WHEN** 用户通过 processTextInput 提交文本
- **THEN** 编排器 SHALL 跳过 AudioCapture/VAD/ASR，直接将文本交给 NLP 解析

#### Scenario: Pre-buffer 防丢字
- **WHEN** VAD 检测到语音开始事件
- **THEN** 编排器 SHALL 将音频 ring buffer 中缓存的 500ms 预语音数据立即发送给 ASR，避免 VAD 触发延迟导致开头丢字

### Requirement: Delegate 模式解耦
编排器 SHALL 通过 VoiceOrchestratorDelegate 接口向 UI 层报告事件。Delegate SHALL 包含以下回调：onSpeechDetected（语音检测到）、onPartialText（中间识别结果）、onFinalText（最终文本+解析结果）、onError（错误信息）、onContinueRecording（连续记账继续监听）。

#### Scenario: Delegate 安全
- **WHEN** 异步回调（如 ASR 错误）在 Notifier 已释放后触发
- **THEN** UI 层 SHALL 通过 _sessionActive 标志忽略该回调，SHALL NOT 修改已释放的 state

### Requirement: 交易确认与保存
编排器 SHALL 在 CONFIRMING 状态支持用户确认、取消或继续追加记账。确认后 SHALL 通过 VoiceTransactionService 将 ParseResult 映射为 TransactionEntity 并持久化到 SQLite。

#### Scenario: 确认保存
- **WHEN** 用户在 CONFIRMING 状态确认交易
- **THEN** 系统 SHALL 匹配分类（模糊匹配优先）、解析默认账户、生成 UUID，保存到 SQLite

#### Scenario: 连续记账
- **WHEN** 用户确认保存后选择继续记账
- **THEN** 系统 SHALL 先保存当前交易，再回到 LISTENING 状态等待下一笔

#### Scenario: 取消当前记录
- **WHEN** 用户通过语音说"不要了"/"取消"或点击取消按钮
- **THEN** 系统 SHALL 丢弃当前解析结果，状态 SHALL 回到 LISTENING

### Requirement: ASR 自动重连
编排器 SHALL 在 ASR WebSocket 意外断连时自动尝试重连。重连 SHALL 使用指数退避策略（1s → 2s → 4s）。最大重连次数 SHALL 为 3 次。重连前 SHALL 使已缓存的 ASR Token 失效以获取新 Token。

#### Scenario: 成功重连
- **WHEN** ASR WebSocket 在 RECOGNIZING 状态意外断连且重连次数 < 3
- **THEN** 系统 SHALL 等待退避时间后重新获取 Token 并建立 WebSocket 连接

#### Scenario: 重连失败
- **WHEN** ASR WebSocket 连续重连 3 次均失败
- **THEN** 系统 SHALL 通过 Delegate.onError 通知用户，状态 SHALL 降级到 LISTENING

#### Scenario: 非 RECOGNIZING 状态不重连
- **WHEN** ASR WebSocket 断连但当前状态为 IDLE 或 LISTENING
- **THEN** 编排器 SHALL NOT 尝试重连
