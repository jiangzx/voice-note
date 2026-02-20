## ADDED Requirements

### Requirement: Barge-in 跨平台一致能力

系统 MUST 在 Android 与 iOS 原生层提供一致的 barge-in 能力：TTS 播放期间检测用户语音意图并中断播放，快速恢复识别输入。Flutter 层 SHALL 仅消费统一事件，不依赖平台特定实现细节。

barge-in 触发语义 MUST 在两平台一致：触发后进入“识别优先态”，并回传触发原因与时间戳。

#### Scenario: 统一触发语义
- **WHEN** Flutter 开启 barge-in 且 TTS 正在播放
- **THEN** Android 与 iOS SHALL 都在检测到有效用户语音时上报 `bargeInTriggered`，并停止当前 TTS

### Requirement: 播放中语音检测与防误触

系统 MUST 在 TTS 播放期间启用原生侧语音活动检测，并支持阈值、最小持续时长、冷却窗口等参数配置。默认配置 SHALL 以“低误触发”为优先，同时保证可打断延迟可接受。

系统 MUST 支持噪声抑制与回声影响控制，避免播放自身语音导致自触发。

#### Scenario: 有效语音打断
- **WHEN** 用户在 TTS 播放中说出明确短句（如“停一下”“不是这个”）
- **THEN** 系统 SHALL 在受控时延内触发 barge-in，并进入识别输入开启状态

#### Scenario: 背景噪声不触发
- **WHEN** TTS 播放中仅存在短暂环境噪声或键盘噪声
- **THEN** 系统 SHALL 不触发 barge-in，保持播放连续

### Requirement: 中断执行时序（先停播再识别）

系统 MUST 保证 barge-in 时序：`检测命中 -> 停止TTS -> 解除ASR门控 -> 上报事件`。该顺序在 Android 与 iOS MUST 一致，以避免播放残留或识别空窗。

系统 MUST 提供中断执行结果事件（成功/失败），失败时 SHALL 自动回退到可恢复状态。

#### Scenario: 中断成功
- **WHEN** barge-in 命中且 TTS 停止成功
- **THEN** 系统 SHALL 上报 `bargeInCompleted(success=true)`，并恢复 ASR 输入

#### Scenario: 中断失败回退
- **WHEN** 停止 TTS 失败或状态不一致
- **THEN** 系统 SHALL 上报 `bargeInCompleted(success=false)`，并执行回退策略保证后续可继续识别

### Requirement: Android 原生实现约束

Android 侧 MUST 在原生音频层实现 barge-in 检测与执行，不得依赖 Flutter 定时轮询。实现 SHALL 与 AudioFocus、AudioAttributes、采集门控协同，避免重复抢焦点。

Android 侧 MUST 在中断后保留常驻采集链路，仅切换识别输入门控状态。

#### Scenario: Android 焦点协同
- **WHEN** barge-in 触发时系统存在焦点变化
- **THEN** Android 原生层 SHALL 先完成停播与门控恢复，再处理焦点重整并上报最终状态

### Requirement: iOS 原生实现约束

iOS 侧 MUST 使用 AVAudioSession/AVAudioEngine 对等实现 barge-in 检测与执行，保证与 Android 相同的外部协议语义。iOS SHALL 处理 route change 与 interruption 回调下的中断一致性。

iOS 侧 MUST 支持在 TTS 中断后快速恢复识别输入，且不中断会话级采集链路。

#### Scenario: iOS 路由变更中打断
- **WHEN** TTS 播放期间发生 route change（如耳机切换）且用户同时发起打断
- **THEN** iOS 原生层 SHALL 保证 barge-in 语义不丢失，并上报可诊断事件序列

#### Scenario: iOS interruption ended 恢复判定
- **WHEN** iOS 收到 interruption ended 且系统指示不可自动恢复
- **THEN** iOS 原生层 SHALL 保持“可恢复但未自动恢复”状态，并上报 `bargeInCompleted(success=false, canAutoResume=false)`

### Requirement: Barge-in 事件载荷标准化

系统 MUST 统一 barge-in 事件载荷字段，至少包含：`sessionId`、`requestId`、`timestamp`、`triggerSource`、`route`、`focusState`、`canAutoResume`。Android 与 iOS SHALL 使用一致字段命名。

#### Scenario: 统一事件字段
- **WHEN** Android 或 iOS 触发 `bargeInTriggered`
- **THEN** 上报事件 SHALL 包含标准化字段集合，Flutter 无需平台分支解析

### Requirement: 前后台切换中的 barge-in 连续性

系统 MUST 在前后台切换期间保持 barge-in 状态一致性。若后台策略导致播放或采集能力变化，原生层 SHALL 记录状态快照并在前台恢复时重建 barge-in 上下文，而非重置为默认状态。

#### Scenario: 前台恢复后的可打断状态
- **WHEN** App 从后台回到前台且会话仍有效
- **THEN** 系统 SHALL 恢复切换前的 barge-in 配置（enabled/threshold/cooldown），并上报状态快照事件

### Requirement: 可观测性与调优

系统 MUST 为 barge-in 提供统一观测指标：触发次数、误触发次数、触发延迟、停播耗时、恢复耗时。Android 与 iOS SHALL 采用统一字段命名，便于跨平台对比。

系统 SHOULD 支持远程或配置下发调优参数（阈值、窗口、冷却时间），并在运行时安全生效。

#### Scenario: 调参与验证
- **WHEN** 调整 barge-in 阈值参数后重新运行语音会话
- **THEN** 系统 SHALL 在指标中体现触发率与误触发率变化，供后续优化决策
