## Why

语音记账页切换到键盘模式后，`ModeSwitcher`（模式切换控件）不再渲染，用户无法切回自动或按住说话模式。这违反了 `voice-recording` spec 中"用户 SHALL 可在语音记账页底部随时切换"的要求，属于功能性回归。

## What Changes

- 修复 `VoiceRecordingScreen` 的布局结构，确保 `ModeSwitcher` 在所有三种输入模式下始终可见
- 当前 `_buildKeyboardInput` 与 `_buildBottomControls` 互斥渲染，`ModeSwitcher` 仅存在于后者。需将 `ModeSwitcher` 提取为独立的、始终渲染的底部组件

## Capabilities

### New Capabilities

无

### Modified Capabilities

- `voice-interaction-ui`: 无 spec 级行为变更（现有 spec 未约束 `ModeSwitcher` 的渲染条件，此为实现层 bug 修复）

## Impact

- **代码**：`voice-note-client/lib/features/voice/presentation/voice_recording_screen.dart` — 调整 `_buildKeyboardInput` 和 `_buildBottomControls` 的布局结构
- **API**：无变更
- **依赖**：无变更
- **测试**：需验证三种模式间可双向切换
