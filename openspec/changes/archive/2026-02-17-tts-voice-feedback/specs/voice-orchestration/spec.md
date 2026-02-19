## Purpose

扩展语音管线编排器，集成 TTS 播报节点，实现播报时抑制 VAD 事件避免回声干扰。

## Requirements

### Requirement: TTS 播报协调
编排器 SHALL 在 TTS 播报期间通过内部标志 `_isTtsSpeaking` 抑制 VAD 事件处理（忽略 speechStart 回调），避免 TTS 声音被 VAD 误判为人声而触发 ASR。AudioCapture SHALL 保持运行（不 stop/restart），播报完成后恢复 VAD 事件响应。播报期间编排器状态 SHALL 保持不变（不引入新状态）。TTS 播报错误 SHALL 被静默捕获，SHALL NOT 中断语音管线。

#### Scenario: 确认播报抑制 VAD
- **WHEN** NLP 解析完成，编排器需要通过 TTS 播报确认信息
- **THEN** 编排器 SHALL 设置 `_isTtsSpeaking=true`，调用 TtsService.speak()，在 speak Future resolve 后设置 `_isTtsSpeaking=false`

#### Scenario: VAD 事件在播报期间被忽略
- **WHEN** TTS 正在播报且 VAD 检测到声音活动（实际是 TTS 声音）
- **THEN** 编排器 SHALL 因 `_isTtsSpeaking=true` 忽略该 VAD speechStart 事件，SHALL NOT 连接 ASR

#### Scenario: 欢迎语播报
- **WHEN** 编排器启动 LISTENING 并且 TTS 已启用
- **THEN** 编排器 SHALL 在 AudioCapture/VAD 启动后立即播报欢迎语，播报期间抑制 VAD 事件

#### Scenario: 保存成功播报
- **WHEN** 交易保存成功且用户选择继续记账
- **THEN** 编排器 SHALL 先播报"记好了，还有吗？"，播报完成后恢复 VAD 事件响应

#### Scenario: TTS 播报失败不影响流程
- **WHEN** TTS 播报过程中抛出异常
- **THEN** 编排器 SHALL 捕获异常、重置 `_isTtsSpeaking=false`，正常继续后续流程
