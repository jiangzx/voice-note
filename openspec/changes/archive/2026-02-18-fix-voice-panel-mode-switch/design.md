## Context

`VoiceRecordingScreen` 的 body 使用 `Column` 布局，底部区域通过 `if/else` 在键盘模式（`_buildKeyboardInput`）和语音模式（`_buildBottomControls`）之间互斥渲染。`ModeSwitcher` 仅位于 `_buildBottomControls` 内部，导致键盘模式下切换控件消失。

当前结构：

```
Column → [
  ...状态组件 (offline/interim/processing/confirmation)
  if (keyboard) → _buildKeyboardInput  ← 无 ModeSwitcher
  else → _buildBottomControls          ← 包含 ModeSwitcher
]
```

## Goals / Non-Goals

**Goals:**
- 确保 `ModeSwitcher` 在所有三种输入模式下始终可见
- 最小改动范围，仅调整布局结构

**Non-Goals:**
- 不改变 `ModeSwitcher` 的外观或行为
- 不修改模式切换的状态管理逻辑（`voiceSessionProvider.switchMode`）
- 不修改 `_buildKeyboardInput` 或语音控件的内部实现

## Decisions

**将 `ModeSwitcher` 从 `_buildBottomControls` 提取到 Column 层级，始终渲染**

修改后结构：

```
Column → [
  ...状态组件 (offline/interim/processing/confirmation)
  if (keyboard) → _buildKeyboardInput     ← 不变
  else → _buildVoiceControls              ← 移除内部的 ModeSwitcher
  _buildModeSwitcher()                     ← 始终渲染，底部固定
]
```

理由：`ModeSwitcher` 是模式间的导航控件，应独立于各模式的内容区域。将其提取为固定底部组件符合 spec 中"随时切换"的要求，且改动面最小——仅涉及 `_buildBottomControls` 方法拆分和 `build` 方法的 Column 调整。

## Risks / Trade-offs

- **布局兼容性**：提取后需确保键盘弹起时 `ModeSwitcher` 不被遮挡 → `Column` 外层已有 `SafeArea`，且键盘模式的输入框在 `ModeSwitcher` 上方，风险低
- **动画连续性**：模式切换时 `ModeSwitcher` 不再随父组件重建 → 实际上是优势，切换更流畅
