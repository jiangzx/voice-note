## ADDED Requirements

### Requirement: 全双工语音控制的跨平台对等能力

系统 MUST 同时在 Android 原生与 iOS 原生提供对等的全双工语音控制能力：常驻采集、识别输入门控、播放期抑制、状态回传。Flutter 侧 SHALL 仅依赖统一协议，不感知平台内部实现差异。

平台能力对等的定义为：相同命令语义、相同事件语义、相同错误分类。各平台允许底层 API 差异，但外部行为 MUST 一致。

#### Scenario: 跨平台行为一致
- **WHEN** Flutter 在 Android 与 iOS 分别调用 `setAsrMuted(true)`
- **THEN** 两个平台 SHALL 都保持麦克风链路存活，仅抑制识别输入，并上报一致的 `asrMuteStateChanged` 事件

### Requirement: ASR 常驻采集 + 门控（Android/iOS）

系统 MUST 在 Android（AudioRecord/等效采集链路）与 iOS（AVAudioEngine input tap/等效采集链路）实现常驻采集，不通过频繁启停录音设备来切换识别状态。

系统 MUST 提供原生级识别输入门控：门控关闭时，采集线程继续运行但不向 ASR 上游投递有效帧；门控开启时，恢复投递并保证切换时延可控。

#### Scenario: 常驻采集稳定
- **WHEN** 会话持续 5 分钟且用户多次发起识别
- **THEN** 系统 SHALL 不因模式切换频繁重建录音设备实例

#### Scenario: 门控切换
- **WHEN** Flutter 连续调用 `setAsrMuted(true)` 与 `setAsrMuted(false)`
- **THEN** 原生层 SHALL 幂等处理并返回最终门控状态，不产生资源泄漏

### Requirement: 播放期输入抑制与恢复

系统 MUST 在 TTS 播放期间自动执行识别输入抑制，播放结束后恢复输入。该策略在 Android 与 iOS 上 MUST 都由原生音频层执行，不依赖 Flutter 定时或插件回调时序。

系统 MUST 支持“强抑制”和“软抑制”两种策略（具体算法可平台实现差异），但对 Flutter 暴露统一策略枚举。

#### Scenario: 播放开始自动抑制
- **WHEN** Flutter 发起 `playTts`
- **THEN** 原生层 SHALL 先切换到抑制状态，再开始播放，并上报 `duplexStateChanged(playback=true, asrMuted=true)`

#### Scenario: 播放结束自动恢复
- **WHEN** TTS 正常结束或被取消
- **THEN** 原生层 SHALL 恢复 ASR 输入，并上报 `duplexStateChanged(playback=false, asrMuted=false)`

### Requirement: 音频焦点与会话中断恢复（Android/iOS）

系统 MUST 在 Android 使用 AudioFocus 回调、在 iOS 使用 AVAudioSession interruption/route change 回调，处理来电、其他媒体抢占、蓝牙路由变化等中断事件。

系统 MUST 在中断后进入可恢复状态，并向 Flutter 上报明确的中断类型和建议动作。

#### Scenario: 短暂焦点丢失
- **WHEN** 发生短暂焦点丢失（如通知音）
- **THEN** 系统 SHALL 暂停播放并保持采集链路可恢复，中断结束后自动恢复到丢失前状态

#### Scenario: 路由变更
- **WHEN** 用户在会话中插拔蓝牙耳机
- **THEN** 系统 SHALL 重新评估输入输出路由并上报 `audioRouteChanged`（含 `oldRoute/newRoute/reason`）

#### Scenario: iOS interruption 恢复判定
- **WHEN** iOS 收到 interruption ended 回调且系统指示不应自动恢复
- **THEN** 系统 SHALL 保持在可恢复但未自动恢复状态，并上报 `audioFocusChanged`（`canAutoResume=false`）

### Requirement: 统一协议与诊断事件

系统 MUST 为全双工控制定义统一协议：命令、事件、错误码与 requestId 关联。Android 与 iOS MUST 返回一致的数据结构，便于 Flutter 统一状态机处理与埋点分析。

系统 MUST 提供关键诊断字段：当前路由、焦点状态、采集状态、门控状态、播放状态、最近错误码。

#### Scenario: 协议可观测性
- **WHEN** Flutter 请求 `getDuplexStatus`
- **THEN** 原生层 SHALL 返回完整状态快照（含 platform、route、focus、capture、gate、playback）

#### Scenario: 错误归一化
- **WHEN** Android 与 iOS 发生各自平台特有错误
- **THEN** 两个平台 SHALL 映射到统一错误分类并上报可读 message 与 rawCode

### Requirement: 前后台切换与状态快照恢复

系统 MUST 在 App 生命周期切换时保持 duplex 状态一致性。进入后台导致采集/播放策略变化时，原生层 SHALL 持久化会话快照（门控、播放、路由、焦点状态），回到前台后按快照恢复，不得强制走全量重初始化。

#### Scenario: 前台恢复
- **WHEN** App 从后台返回前台
- **THEN** 系统 SHALL 基于最近状态快照恢复 duplex 状态，并向 Flutter 上报 `duplexStateChanged` 快照事件

### Requirement: 播放自触发抑制

系统 MUST 提供播放自触发抑制能力，防止 TTS 输出被误判为用户语音触发 ASR 或 barge-in。该能力在 Android 与 iOS 上 MUST 都生效，具体算法可不同，但外部效果必须一致。

#### Scenario: TTS 自回采防护
- **WHEN** TTS 播放中采集到与播放内容高度相关的短时能量峰值
- **THEN** 系统 SHALL 优先判定为播放泄漏而非用户输入，不触发 barge-in 且不向 ASR 上游投递
