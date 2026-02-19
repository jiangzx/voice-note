## Purpose

更新超时预警 Scenario，从"Phase 3 计划"标注变更为正式 TTS 实现。

## Requirements

### Requirement: 超时预警 TTS 播报
系统 SHALL 在 LISTENING 状态连续 2分30秒无人声时通过 TTS 播报预警。

#### Scenario: 超时预警（更新）
- **WHEN** 状态为 LISTENING 且连续 2 分 30 秒无人声
- **THEN** 系统 SHALL 通过 TtsService 播报"还在吗？30秒后我就先走啦"
- **THEN** 若 TTS 不可用，SHALL 以系统消息文本形式展示
