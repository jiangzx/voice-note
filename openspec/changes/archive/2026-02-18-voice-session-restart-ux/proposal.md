## Why

当前语音会话结束后（用户说"没有了"或超时），系统直接销毁 orchestrator 并导航离开语音页面。用户若想继续记账，需重新进入语音页面、等待初始化和欢迎语播报，体验中断感强。用户更自然的期望是：会话结束后留在语音页面，一键即可开始新一轮。

## What Changes

- 退出语音会话后不再自动导航离开语音页面，而是停留在页面并显示"会话已结束"状态
- 在会话结束状态下显示明显的重启入口（浮动按钮或居中提示按钮），用户轻触即可开始新会话
- 会话结束时仍然播报退出总结 TTS 并显示 session summary
- 超时退出和主动退出（"没有了"/"退出"）使用相同的结束态 UI
- 页面左上角返回按钮或系统返回手势仍可离开语音页面

## Capabilities

### New Capabilities

（无新增独立 capability）

### Modified Capabilities

- `voice-orchestration`: 退出会话后的状态变更 — 新增 `ended` 状态（区别于 `idle`），在该状态下语音服务已释放但页面仍保留，支持通过 UI 操作重新启动 session

## Impact

- `voice-note-client/lib/features/voice/domain/voice_state.dart` — 新增 `VoiceState.ended` 枚举值
- `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart` — `onExitSession` / `onSessionTimeout` 不再调用导航，改为设置 ended 状态
- `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart` — 新增 ended 状态的 UI（session summary + 重启按钮）
- 不涉及服务端改动
- 不涉及 API 变更
