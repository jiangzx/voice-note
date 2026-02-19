## Context

当前语音会话退出流程（`onExitSession` / `onSessionTimeout`）调用 `endSession()` → `dispose()` orchestrator → 清空 `VoiceSessionState`。`VoiceRecordingScreen` 监听 state 中的 `voiceState == idle` 并触发 `Navigator.pop()`，导致用户离开语音页面。

用户反馈：说 "没有了" 退出后想继续记账，需要重新进入语音页面，体验不连贯。

## Goals / Non-Goals

**Goals:**
- 语音会话结束后留在语音页面，显示 session summary + 重启按钮
- 一键重启新会话，无需重新导航
- 超时退出和主动退出使用统一的结束态 UI
- 保留系统返回手势/按钮离开页面的能力

**Non-Goals:**
- 不改变 auto/pushToTalk/keyboard 模式切换逻辑
- 不改变会话中的状态机流转（listening ↔ recognizing ↔ confirming）
- 不引入后台持续监听（ended 状态下音频服务完全释放）

## Decisions

### D1: 新增 `VoiceState.ended` 枚举值

**选择：** 在 `VoiceState` 中新增 `ended` 状态，与 `idle` 区分。

| 方案 | 优点 | 缺点 |
|------|------|------|
| A. 新增 `ended` 状态 | 语义清晰，UI 可精确匹配 | 需更新所有 state 判断 |
| B. 复用 `idle` + `VoiceSessionState.hasSessionSummary` 标志 | 不改 enum | idle 语义模糊，需额外字段 |

**选择 A**：`ended` 语义明确 — 表示 "会话已结束但仍在语音页面"。`idle` 保留 "未进入会话" 的原始含义。

### D2: 会话结束后的资源管理

**选择：** `ended` 状态下完全释放音频资源（与当前 `endSession` 行为一致），仅保留 UI state（messages、summary）。重启时重新创建 orchestrator。

**理由：** 持有麦克风和 VAD 会消耗电量和系统资源。用户可能在 ended 状态停留较长时间，不应浪费资源。

### D3: 重启入口 UI 形态

**选择：** 居中卡片式提示 + 按钮（"记好了！点击开始新一轮"），替代 chat 输入区域。

| 方案 | 优点 | 缺点 |
|------|------|------|
| A. 居中卡片 + 按钮 | 醒目、操作路径短 | 需新 widget |
| B. FAB 浮动按钮 | 标准 Material 模式 | 可能被 chat 记录遮挡 |
| C. 底部 banner | 不遮挡 summary | 视觉权重低 |

**选择 A**：居中卡片在聊天记录底部，与 summary 消息紧邻，视觉流畅。

### D4: 导航行为变更

**选择：** `VoiceRecordingScreen` 不再在 `voiceState == idle` 时自动 pop，改为仅在用户主动返回时 pop。`ended` 状态显示重启 UI。

## Risks / Trade-offs

- **[风险]** 用户习惯了自动退出可能困惑 → 通过 session summary + TTS 退出播报明确告知会话已结束
- **[风险]** ended 状态停留过久占用内存 → messages 列表有上限（现有机制），orchestrator 已释放
- **[权衡]** 新增 `ended` 状态需更新所有 `switch(voiceState)` 分支 → 影响有限，voice_recording_screen 中约 3-4 处
