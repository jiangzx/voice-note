## Purpose

更新连续记账退出时的汇总行为，从文本消息升级为 TTS 语音播报。

## Requirements

### Requirement: 退出汇总 TTS 播报
系统 SHALL 在用户退出语音会话时通过 TTS 播报会话汇总。

#### Scenario: 用户主动退出（更新）
- **WHEN** 用户说"没了"或"拜拜"，或通过返回键/手势退出
- **THEN** 若本次会话有已保存的交易且 TTS 已启用，系统 SHALL 通过 TTS 播报汇总（"本次记了N笔，共X元，拜拜"），播报完成后返回上一页
- **THEN** 若 TTS 未启用或不可用，SHALL 以系统消息文本形式展示汇总
