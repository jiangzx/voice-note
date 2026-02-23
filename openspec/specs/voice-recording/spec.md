## Purpose

定义客户端语音记账的核心系统行为，包括语音状态机管理、VAD 语音活动检测、ASR 实时语音识别、输入模式切换（含手动模式按住说话与上滑取消）、ASR 断连通知和错误处理。

## Requirements

### Requirement: 语音状态机管理
系统 SHALL 维护一个四态状态机管理语音记账的生命周期。状态 SHALL 包含：IDLE（待机）、LISTENING（监听）、RECOGNIZING（识别中）、CONFIRMING（确认中）。状态流转 SHALL 由用户交互和 VAD/ASR 事件驱动。

#### Scenario: 进入语音记账页
- **WHEN** 用户导航至语音记账页
- **THEN** 状态 SHALL 从 IDLE 切换为 LISTENING，麦克风 SHALL 开启，VAD SHALL 启动

#### Scenario: VAD 检测到人声
- **WHEN** 状态为 LISTENING 且 VAD 检测到有效人声（持续 ≥500ms）
- **THEN** 状态 SHALL 切换为 RECOGNIZING，系统 SHALL 启动 ASR 连接

#### Scenario: ASR 返回识别结果
- **WHEN** 状态为 RECOGNIZING 且 ASR 返回完整文本（静音 ≥800ms 触发）
- **THEN** 系统 SHALL 对文本进行 NLP 解析，解析完成后状态 SHALL 切换为 CONFIRMING

#### Scenario: 用户确认交易
- **WHEN** 状态为 CONFIRMING 且用户通过语音或点击确认
- **THEN** 系统 SHALL 保存交易记录到本地 SQLite，状态 SHALL 回到 LISTENING

#### Scenario: 超时退出
- **WHEN** 状态为 LISTENING 且连续 3 分钟无人声
- **THEN** 系统 SHALL 自动退出语音记账页，返回首页
- **NOTE**: 超时计时器在进入 LISTENING 后启动，任何语音交互（包括确认/取消/继续）重置计时

#### Scenario: 超时预警
- **WHEN** 状态为 LISTENING 且连续 2 分 30 秒无人声（距 3 分钟超时前 30 秒）
- **THEN** 系统 SHALL 通过 TtsService 播报「还在吗？暂时不用的话我会先休息哦，30秒后自动退出」（当前实现见 TtsTemplates.timeout / VoiceCopy.timeoutWarningMain+Sub）
- **THEN** 若 TTS 不可用，SHALL 以系统消息文本形式展示

### Requirement: 本地 VAD 语音活动检测
系统 SHALL 使用 Silero VAD 在设备端运行语音活动检测。VAD SHALL 以 32ms 为单位分析音频帧（16kHz, 512 samples/frame）。VAD 运行时 SHALL NOT 发送任何网络请求。VAD 参数 SHALL 可配置。

#### Scenario: 有效语音检测
- **WHEN** 用户在安静环境说"午饭35"（约 1.5 秒）
- **THEN** VAD SHALL 在语音开始后 ≤3 帧（~96ms）内检测到人声并发出语音开始事件

#### Scenario: 静音判定
- **WHEN** 用户说完话后静默 ≥8 帧（~256ms）
- **THEN** VAD SHALL 发出语音结束事件

### Requirement: ASR 实时语音识别
系统 SHALL 通过 DashScope ASR WebSocket 进行实时流式语音识别。ASR 连接 SHALL 使用从 Server 获取的临时 Token 认证。ASR SHALL 实时返回中间识别结果。

#### Scenario: ASR Token 获取与连接
- **WHEN** VAD 检测到有效人声且需要启动 ASR
- **THEN** 系统 SHALL 先调用 Server `POST /api/v1/asr/token` 获取临时 Token，然后使用该 Token 建立 DashScope ASR WebSocket 连接

#### Scenario: 实时识别结果展示
- **WHEN** ASR WebSocket 连接建立且用户正在说话
- **THEN** 系统 SHALL 将中间识别结果实时更新到 UI

#### Scenario: ASR Token 获取失败
- **WHEN** Server 不可达或返回错误
- **THEN** 系统 SHALL 提示用户切换到手动输入模式，SHALL NOT 阻塞整体记账流程

#### Scenario: Token 复用
- **WHEN** 临时 Token 尚未过期且需要新的 ASR 会话
- **THEN** 系统 SHALL 复用现有 Token，不重新请求

### Requirement: 输入模式切换
系统 SHALL 支持三种输入模式：自动模式（VAD 自动检测）、按住说话（PTT）、键盘输入。默认 SHALL 为自动模式。用户 SHALL 可在语音记账页底部随时切换。模式切换控件 SHALL 在所有三种输入模式下始终可见。用户的默认模式偏好 SHALL 可在设置中配置并持久化。

#### Scenario: 自动模式工作
- **WHEN** 输入模式为"自动"且 VAD 检测到人声
- **THEN** 系统 SHALL 自动启动 ASR 识别

#### Scenario: 按住说话模式工作
- **WHEN** 输入模式为"按住说话"且用户按下录音按钮
- **THEN** 系统 SHALL 在按住期间录音并发送到 ASR；松开时结束本次输入

#### Scenario: 松开发送
- **WHEN** 用户按住说话后未上滑至取消区即松开
- **THEN** 系统 SHALL 提交当前音频并执行 ASR 识别与 NLP 解析（等同于 pushEnd）

#### Scenario: 上滑取消
- **WHEN** 用户按住说话后上滑超过约定阈值并松开
- **THEN** 系统 SHALL 取消本次录音：提交当前音频以清空服务端缓冲、丢弃该次识别结果、状态 SHALL 回到 LISTENING（不进入 CONFIRMING）

#### Scenario: 滑回发送
- **WHEN** 用户上滑进入取消区后再次下滑回发送区并松开
- **THEN** 系统 SHALL 按松开发送处理，提交并识别本次录音

#### Scenario: 取消后下次识别独立
- **WHEN** 用户完成一次上滑取消后再次按住说话并松开发送
- **THEN** 系统 SHALL 仅识别并处理第二次录音内容，SHALL NOT 将第一次取消段的文本并入结果

#### Scenario: 切换到键盘输入
- **WHEN** 用户在语音记账页切换到键盘输入模式
- **THEN** 系统 SHALL 关闭麦克风和 VAD，展示文字输入框

#### Scenario: 从键盘切回语音模式
- **WHEN** 用户从键盘模式切换到自动或按住说话模式
- **THEN** 系统 SHALL 重新启动麦克风和 VAD

#### Scenario: 键盘模式下模式切换控件可见
- **WHEN** 用户处于键盘输入模式
- **THEN** 模式切换控件 SHALL 保持可见，用户 SHALL 可切换到自动或按住说话模式

### Requirement: VAD 误触建议
当 VAD 在自动模式下连续误触 3 次（检测到语音但实际为噪音）时，系统 SHALL 建议用户切换到「按住说话」模式以减少干扰。

#### Scenario: 连续误触建议切换
- **WHEN** VAD 在自动模式下连续误触 3 次（触发 VADMisfire 事件）
- **THEN** 系统 SHALL 通过系统消息提示用户切换到「按住说话」模式

#### Scenario: 真实语音重置计数
- **WHEN** VAD 检测到真实语音（持续超过最小帧数）
- **THEN** 系统 SHALL 重置连续误触计数器

### Requirement: ASR WebSocket 断连通知
AsrWebSocketService SHALL 在 WebSocket 意外断开时向订阅方发出 disconnected 事件。主动调用 disconnect() SHALL NOT 触发 disconnected 事件。断连通知 SHALL 携带原因信息（如有）。

#### Scenario: 意外断连
- **WHEN** ASR WebSocket 在 RECOGNIZING 状态因网络波动断开
- **THEN** AsrWebSocketService SHALL 通过事件流发出 disconnected 事件

#### Scenario: 主动断开不通知
- **WHEN** 编排器调用 disconnect() 主动关闭 WebSocket
- **THEN** AsrWebSocketService SHALL NOT 发出 disconnected 事件

### Requirement: 语音管线错误处理
系统 SHALL 为语音管线各环节定义域级异常。SHALL 包含：AudioCaptureException（麦克风采集失败）、VadServiceException（VAD 启动失败）、AsrTokenException（Token 获取失败）、LlmParseException（LLM 解析失败）、VoiceSaveException（交易保存失败）。各层 SHALL 捕获底层异常并包装为域级异常向上抛出。

#### Scenario: 麦克风采集失败
- **WHEN** AudioCaptureService.start() 因权限问题失败
- **THEN** 系统 SHALL 抛出 AudioCaptureException，编排器 SHALL 通过 Delegate.onError 通知 UI

#### Scenario: 保存失败
- **WHEN** VoiceTransactionService.save() 因数据库约束失败
- **THEN** 系统 SHALL 抛出 VoiceSaveException，UI SHALL 展示 error 消息并保留确认卡片供重试
