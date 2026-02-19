## 1. Domain 层 — 状态定义

- [x] 1.1 在 `VoiceState` 枚举中新增 `ended` 值
  `voice-note-client/lib/features/voice/domain/voice_state.dart`

- [x] 1.2 更新 `VoiceState` 相关测试，确保 `ended` 被正确覆盖
  `voice-note-client/test/features/voice/domain/voice_state_test.dart`

## 2. Presentation 层 — Provider 改造

- [x] 2.1 修改 `VoiceSessionNotifier.onExitSession` — 不再调用 `endSession()`，改为设置 `voiceState = ended`，释放 orchestrator 但保留 messages 和 summary
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 2.2 修改 `VoiceSessionNotifier.onSessionTimeout` — 同样设置 `ended` 状态而非调用 `endSession()`
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 2.3 新增 `VoiceSessionNotifier.restartSession()` 方法 — 清空 messages/summary、重新创建 orchestrator、开始监听
  `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`

- [x] 2.4 更新 `VoiceSessionNotifier` 单元测试：覆盖 exit → ended 状态转换、timeout → ended、restart 流程
  `voice-note-client/test/features/voice/presentation/providers/voice_session_provider_test.dart`

## 3. Presentation 层 — UI 改造

- [x] 3.1 修改 `VoiceRecordingScreen` 移除 `voiceState == idle` 时自动 pop 的逻辑
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 3.2 新增 `SessionEndedCard` widget — 显示 session summary + "开始新一轮" 按钮
  `voice-note-client/lib/features/voice/presentation/widgets/session_ended_card.dart`

- [x] 3.3 在 `VoiceRecordingScreen` 中当 `voiceState == ended` 时显示 `SessionEndedCard` 替代输入区域
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 3.4 确保系统返回手势/AppBar 返回按钮在 `ended` 状态下正常导航离开
  `voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart`

- [x] 3.5 Widget 测试：验证 `ended` 状态显示 `SessionEndedCard`、点击重启按钮触发 `restartSession`
  `voice-note-client/test/features/voice/presentation/widgets/session_ended_card_test.dart`

## 4. 集成验证

- [x] 4.1 运行全部客户端测试确认无回归
- [ ] 4.2 在模拟器上手动验证完整流程：记账 → 确认 → "没有了" → 看到重启按钮 → 点击重启 → 继续记账
