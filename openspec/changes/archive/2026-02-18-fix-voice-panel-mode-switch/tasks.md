## 1. 布局重构

- [x] 1.1 将 `ModeSwitcher` 从 `_buildBottomControls` 中提取，作为独立方法 `_buildModeSwitcher()`
- [x] 1.2 在 `build` 方法的 `Column` 中，将 `_buildModeSwitcher()` 放在 `_buildKeyboardInput` / `_buildVoiceControls` 的 if/else 块之后，始终渲染
- [x] 1.3 将原 `_buildBottomControls` 重命名为 `_buildVoiceControls`，仅保留语音动画/PTT 按钮和状态文本

## 2. 验证

- [ ] 2.1 在模拟器上验证：自动模式 → 键盘模式 → 按住说话模式，三种模式间双向切换均正常
- [x] 2.2 运行 `flutter test` 确保无回归
