# Native Audio Runtime QA

本文档用于执行 `native-audio-layer-for-voice-dialogue` 的真机验证，覆盖 Android/iOS/E2E。

## 0. 测试前准备

- 测试构建：使用当前分支最新 Debug 包。
- 日志采集：
  - Flutter: 观察 `VoiceTelemetry`（含 `bargeInLatencyMs`、`ttsStopCostMs`、`resumeCostMs`、`focusLossCount`、`falseTriggerCount`）。
  - Android: `adb logcat` 过滤应用进程。
- 设备建议：
  - Android 至少 2 台（如 Pixel + 国产机），系统版本尽量覆盖 Android 12/14。
  - 每台设备至少验证：外放、蓝牙耳机、有线耳机（如可用）。
- 环境建议：
  - 安静环境 + 噪声环境（地铁/商场录音回放）。
  - 网络正常 + 弱网（可通过限速工具模拟）。

## 1. Android 真机验证（任务 5.1）

### 1.1 目标

- 自动模式 / PTT 模式 / 键盘模式切换时，ASR 采集链路常驻。
- 不出现频繁麦克风重建（无明显 stop/start 抖动）。
- 模式切换与对话链路稳定，无明显回归。

### 1.2 用例矩阵

| 用例 ID | 场景 | 预期 |
|---|---|---|
| A-01 | 自动模式启动后静默 60s | 采集链路保持，不卡死，不退出 |
| A-02 | 自动模式连续说 10 轮 | 每轮可识别，未见麦克风反复重建 |
| A-03 | 自动模式中 TTS 播放 + barge-in | TTS 被打断，识别恢复，事件顺序正确 |
| A-04 | 自动 -> PTT -> 自动 | 模式切换后都可用，状态一致 |
| A-05 | 自动 -> 键盘 -> 自动 | 键盘期间不误触发语音，切回后恢复 |
| A-06 | 蓝牙耳机插拔中对话 | 路由变化有事件，识别与播放不中断或可恢复 |
| A-07 | 来电/通知打断后恢复 | 焦点变化上报，可恢复策略符合预期 |

### 1.3 执行步骤（核心流程）

1. 启动 App，进入语音页面，选择自动模式。  
2. 观察启动阶段是否上报 `runtimeInitialized`。  
3. 进行 10 轮短句输入（每轮 3-5 秒）。  
4. 每轮确认：
   - 有 ASR 结果返回；
   - TTS 可正常播报；
   - 若用户说话打断，出现 `bargeInTriggered -> ttsStopped/ttsCompleted -> bargeInCompleted`。  
5. 切换到 PTT，按住说话 5 轮，再切回自动 5 轮。  
6. 切换到键盘输入并提交 3 次，再切回自动。  
7. 在对话中执行蓝牙耳机连接/断开各 1 次。  
8. 在 TTS 播放中触发通知音或短暂打断，验证恢复行为。  

### 1.4 采集与判定标准

- **ASR 常驻判定（必须）**
  - 长会话中没有明显“每轮重新申请麦克风”的可感知卡顿；
  - 日志未出现高频 stop/start 重建模式。
- **模式切换判定（必须）**
  - 自动/PTT/键盘切换后均可正常工作；
  - 无“按住模式等同自动模式”的回归。
- **barge-in 判定（必须）**
  - 打断成功率 >= 90%（10 次至少 9 次）；
  - `bargeInLatencyMs`、`ttsStopCostMs`、`resumeCostMs` 有稳定数值，无异常尖峰。
- **稳定性判定（必须）**
  - 连续 10 分钟测试不崩溃、不假死；
  - `focusLossCount`、`falseTriggerCount` 可解释且不异常飙升。

### 1.5 结果记录模板

| 设备 | 系统 | 路由 | 用例 ID | 结果(P/F) | 关键日志/指标 | 备注 |
|---|---|---|---|---|---|---|
| Pixel 8 | Android 14 | Speaker | A-03 | P | bargeInLatencyMs=180 | - |

### 1.6 阻塞与回归处理建议

- 若出现 TTS 可播但 ASR 失效：优先检查 `asrMuteStateChanged` 是否未恢复。
- 若出现打断后无恢复：检查 `ttsStopped/ttsCompleted` 后是否收到 `asrMuted=false`。
- 若出现模式错乱：检查 `switchInputMode` 调用与事件时序是否一致。

## 2. iOS 真机验证（任务 5.2）

待执行。将重点覆盖 interruption、route change、前后台切换，以及 `canAutoResume` 与快照恢复一致性。

## 3. E2E 对话验证（任务 5.3）

待执行。将重点覆盖 TTS 稳定播放、播放期 ASR 不污染、barge-in 成功率与体验指标。
