## ADDED Requirements

### Requirement: 原生音频运行时主导设备音频会话

系统 MUST 在 Android 原生层维护单一音频运行时实例，统一管理麦克风采集、播放焦点、输出路由与会话状态。Flutter 层 SHALL 仅通过平台通道发送控制命令与接收状态事件，不直接控制底层音频策略。

原生音频运行时 MUST 在单次语音会话内维持稳定状态机，避免因 Flutter 页面状态变化导致底层录音/播放对象反复重建。

#### Scenario: 会话初始化

- **WHEN** Flutter 发起 `initializeSession`
- **THEN** 原生层 SHALL 完成录音引擎、播放引擎与焦点管理器初始化，并返回可用状态

#### Scenario: 状态回传

- **WHEN** 原生音频状态发生变化（如 focus 获得/丢失、路由变更、内部错误）
- **THEN** 原生层 SHALL 通过事件通道向 Flutter 上报结构化状态事件

### Requirement: ASR 常驻采集与可控抑制

系统 MUST 支持 ASR 常驻采集模型：麦克风采集链路在会话存续期间保持开启，不通过频繁 stop/start 控制识别段落。系统 SHALL 通过 `mute/unmute` 或等效门控机制控制“采集数据是否进入识别输入”。

系统 MUST 支持识别输入门控切换延迟受控，防止因门控切换导致前导语音丢失或尾部截断。

#### Scenario: 常驻采集

- **WHEN** 语音会话进入 listening
- **THEN** 原生层 SHALL 保持麦克风采集持续运行

#### Scenario: 输入抑制

- **WHEN** Flutter 发起 `setAsrMuted(true)`
- **THEN** 原生层 SHALL 继续采集但停止向 ASR 上游投递有效音频帧

#### Scenario: 输入恢复

- **WHEN** Flutter 发起 `setAsrMuted(false)`
- **THEN** 原生层 SHALL 在受控时延内恢复向 ASR 上游投递音频帧

### Requirement: TTS 播放与采集解耦

系统 MUST 在 TTS 播放期间保障输出稳定，不受 ASR 输入链路干扰。TTS 播放策略 SHALL 由原生层统一管理 AudioAttributes、AudioFocus 请求与恢复流程。

系统 MUST 在 TTS 播放前后自动协调 ASR 输入门控：播放开始前抑制识别输入，播放结束后按策略恢复识别输入。

#### Scenario: 播放开始

- **WHEN** Flutter 发起 `playTts(text, requestId)`
- **THEN** 原生层 SHALL 先完成 ASR 输入抑制与焦点准备，再开始播放，并回传 `ttsStarted(requestId)`

#### Scenario: 播放结束

- **WHEN** TTS 正常播放完成
- **THEN** 原生层 SHALL 回传 `ttsCompleted(requestId)` 并恢复 ASR 输入门控

#### Scenario: 播放失败

- **WHEN** TTS 引擎不可用或播放异常
- **THEN** 原生层 SHALL 回传可诊断错误事件，并确保 ASR 输入门控恢复到可识别状态

### Requirement: Barge-in 中断机制

系统 MUST 支持 TTS 播放期间用户语音打断（barge-in）。当原生层检测到有效打断信号时，MUST 立即中止当前 TTS 播放并切换到识别优先路径。

barge-in 判定 SHALL 由原生层基于可配置阈值与窗口实现，以降低误触发概率。

#### Scenario: 有效打断

- **WHEN** TTS 播放中检测到满足阈值的用户语音
- **THEN** 原生层 SHALL 触发 `bargeInTriggered`，停止当前 TTS，并恢复 ASR 输入

#### Scenario: 无效噪声

- **WHEN** TTS 播放中仅检测到低强度背景噪声
- **THEN** 原生层 SHALL 不触发 barge-in，继续当前播放

### Requirement: Flutter 与原生协议一致性

系统 MUST 定义稳定的 Flutter ↔ Android 协议：命令接口、事件模型、错误码与幂等语义。所有关键命令 MUST 可重复调用且行为可预期。

系统 MUST 为每个异步命令提供 requestId 关联能力，确保 Flutter 可正确匹配原生回调事件。

#### Scenario: 幂等初始化

- **WHEN** Flutter 重复调用 `initializeSession`（会话已初始化）
- **THEN** 原生层 SHALL 返回成功且不重复构建底层资源

#### Scenario: 事件关联

- **WHEN** 同时存在多个异步命令（如连续 TTS 请求）
- **THEN** 原生层回传事件 SHALL 携带 requestId，Flutter SHALL 能准确关联到对应命令

### Requirement: iOS 音频会话生命周期规范

系统 MUST 在 iOS 原生层基于 `AVAudioSession` 执行确定性的会话生命周期管理，至少包含：category/mode 配置、`setActive` 时序、中断恢复、路由变化回调处理。iOS 与 Android 对外事件语义 MUST 保持一致。

iOS 默认会话策略 MUST 优先选择可提供语音对话增强能力的配置（如 `playAndRecord` + `voiceChat` 或等效能力）。若因设备兼容性降级，系统 MUST 上报降级事件与原因。

#### Scenario: setActive 时序

- **WHEN** Flutter 调用 `initializeSession`
- **THEN** iOS 原生层 SHALL 先完成 category/mode 配置，再激活会话；在 `disposeSession` 时按规范反激活并通知其他音频会话

#### Scenario: iOS 配置降级

- **WHEN** 目标会话配置不可用或激活失败
- **THEN** iOS 原生层 SHALL 降级到预定义备选配置，并上报 `runtimeWarning`（含 `reason` 与 `fallbackMode`）

