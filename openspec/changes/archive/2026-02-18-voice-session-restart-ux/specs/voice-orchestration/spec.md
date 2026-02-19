## ADDED Requirements

### Requirement: 会话结束态与一键重启

系统 SHALL 在语音会话结束后进入 `ended` 状态。`ended` 状态下，系统 SHALL 释放所有音频资源（麦克风、VAD、ASR WebSocket），但 SHALL 保留会话消息记录和 session summary。系统 SHALL 在 `ended` 状态下提供重启入口，用户操作后 SHALL 启动全新会话。

#### Scenario: 用户主动退出后显示重启入口
- **WHEN** 用户在会话中说 "没有了" / "退出" / "结束" 等退出指令
- **THEN** 系统 SHALL 播报 session summary TTS、设置状态为 `ended`、显示重启入口
- **THEN** 系统 SHALL NOT 自动导航离开语音页面

#### Scenario: 超时退出后显示重启入口
- **WHEN** 语音会话因 3 分钟无操作超时
- **THEN** 系统 SHALL 显示超时提示、设置状态为 `ended`、显示重启入口
- **THEN** 系统 SHALL NOT 自动导航离开语音页面

#### Scenario: 用户点击重启按钮
- **WHEN** 用户在 `ended` 状态下点击重启按钮
- **THEN** 系统 SHALL 清空历史消息、创建新的 orchestrator、开始监听
- **THEN** 状态 SHALL 从 `ended` 变为 `listening`

#### Scenario: 用户通过系统返回手势离开
- **WHEN** 用户在 `ended` 状态下按返回按钮或执行返回手势
- **THEN** 系统 SHALL 导航离开语音页面

## MODIFIED Requirements

### Requirement: 编排器退出会话行为

编排器 SHALL 在收到退出指令后将状态设置为 `idle`（而非由外层驱动页面导航）。外层 SHALL 根据 `onExitSession` / `onSessionTimeout` 回调决定是否进入 `ended` 状态。编排器 SHALL 在退出时释放所有音频资源。

#### Scenario: 编排器退出后 VAD 不再触发
- **WHEN** 编排器状态变为 `idle`（退出）
- **THEN** VAD 事件 SHALL NOT 触发 ASR 连接
- **THEN** 所有 stream subscription SHALL 被取消
