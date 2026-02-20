## 背景与目标

本变更要解决当前语音链路的结构性问题：  
1) PTT/自动模式边界不稳定；2) TTS 与 ASR 互相干扰；3) 平台差异导致行为不可预测。  

目标是构建“行业级语音对话”基础能力：
- ASR 常驻采集（不频繁开关麦克风）
- TTS 稳定播放且不被 ASR 污染
- 播放期间支持用户打断（barge-in）
- Android/iOS 对外协议一致，Flutter 统一编排

## 设计原则

- **原生优先**：底层音频控制（焦点、路由、采集、播放、门控）在平台原生实现
- **Flutter 编排**：Flutter 负责会话状态机、业务语义与 UI，不直接操作底层音频参数
- **单一音频运行时**：每个平台维护单例 runtime，避免频繁重建导致时序抖动
- **协议先行**：Flutter ↔ Native 使用稳定命令/事件协议，所有异步操作带 `requestId`
- **能力对等**：Android/iOS 对外行为一致，内部 API 可不同

## 分层架构

### 1) Flutter 层（业务编排层）

- `VoiceOrchestrator`：会话状态机（idle/listening/recognizing/confirming）
- `NativeAudioGateway`（新增）：MethodChannel/EventChannel 封装
- `VoiceSessionNotifier`：UI 状态与原生事件桥接

职责：
- 发命令：初始化会话、切换模式、播放/停止 TTS、设置 ASR 门控
- 收事件：路由变化、TTS 生命周期、barge-in 触发、错误告警
- 决策策略：何时允许打断、何时恢复识别、何时进入确认态

### 2) Native Runtime 层（Android/iOS）

统一抽象：
- `AudioRuntimeController`
- `CaptureEngine`（常驻采集）
- `AsrGate`（mute/unmute 门控）
- `TtsEngine`（播放与中断）
- `BargeInDetector`（播放期语音检测）
- `FocusRouteManager`（焦点与路由）

职责：
- 管理设备音频会话生命周期
- 保持采集链路常驻，门控识别输入
- TTS 播放与门控/焦点协同
- barge-in 原生判定与时序执行

### 3) 平台实现层

- Android：`AudioRecord` + `AudioTrack/TTS` + `AudioManager/AudioFocus`
- iOS：`AVAudioEngine` + `AVSpeechSynthesizer` + `AVAudioSession`

## 能力归属（必须原生 vs 保留 Flutter）

### 必须在原生实现

- 音频焦点申请/恢复（AudioFocus / AVAudioSession interruption）
- 音频路由与设备切换（扬声器/耳机/蓝牙）
- 常驻采集线程与缓冲管理
- ASR 输入门控（采集继续、上游投递开关）
- TTS 播放生命周期（start/progress/end/error/cancel）
- barge-in 检测与“先停播再恢复识别”的硬时序

### 保留在 Flutter

- 会话业务状态机与交互逻辑（自动/PTT/键盘）
- NLP 调用与确认流转（parse/correct/save）
- UI 反馈与动画
- 原生事件消费与策略参数下发（阈值、开关、模式）

## Flutter ↔ Native 通道协议设计

### MethodChannel

channel: `voice_note/native_audio`

1. `initializeSession(Map args)`
- args: `{ sessionId, mode, sampleRate, channels, enableBargeIn, platformConfig }`
- return: `{ ok, runtimeState, capabilities }`

2. `disposeSession(Map args)`
- args: `{ sessionId }`
- return: `{ ok }`

3. `setAsrMuted(Map args)`
- args: `{ sessionId, muted, reason }`
- return: `{ ok, muted }`

4. `playTts(Map args)`
- args: `{ sessionId, requestId, text, locale, speechRate, interruptible }`
- return: `{ ok, requestId }`

5. `stopTts(Map args)`
- args: `{ sessionId, requestId?, reason }`
- return: `{ ok }`

6. `setBargeInConfig(Map args)`
- args: `{ sessionId, enabled, energyThreshold, minSpeechMs, cooldownMs }`
- return: `{ ok }`

7. `getDuplexStatus(Map args)`
- args: `{ sessionId }`
- return: `{ captureActive, asrMuted, ttsPlaying, focusState, route, lastError }`

8. `switchInputMode(Map args)`
- args: `{ sessionId, mode }` // auto | pushToTalk | keyboard
- return: `{ ok, mode }`

9. `getLifecycleSnapshot(Map args)`
- args: `{ sessionId }`
- return: `{ appState, captureActive, asrMuted, ttsPlaying, focusState, route, bargeInConfig }`

10. `restoreLifecycleSnapshot(Map args)`
- args: `{ sessionId, snapshot }`
- return: `{ ok, restoredFields }`

### EventChannel

channel: `voice_note/native_audio/events`

事件统一结构：
`{ event, sessionId, requestId?, timestamp, data, error? }`

barge-in 事件标准载荷（Android/iOS 一致）：
`{ sessionId, requestId, timestamp, triggerSource, route, focusState, canAutoResume }`

核心事件：
- `runtimeInitialized`
- `asrMuteStateChanged`
- `ttsStarted` / `ttsCompleted` / `ttsStopped` / `ttsError`
- `bargeInTriggered` / `bargeInCompleted`
- `audioFocusChanged`
- `audioRouteChanged`
- `runtimeError`

语义补充：
- `bargeInCompleted` MUST 包含 `success` 与 `canAutoResume`
- `audioRouteChanged` MUST 包含 `oldRoute/newRoute/reason`
- `audioFocusChanged` 在 interruption ended 场景下 MUST 包含 `canAutoResume`

## Android 关键实现（Kotlin 伪代码）

### 1) ASR 常驻采集 + 可门控

```kotlin
class AsrCaptureRuntime(
  private val recorder: AudioRecord,
  private val asrSink: (ByteArray) -> Unit
) {
  @Volatile private var running = false
  @Volatile private var asrMuted = false

  fun start() {
    if (running) return
    running = true
    recorder.startRecording()
    thread(name = "asr-capture") {
      val buf = ByteArray(3200)
      while (running) {
        val n = recorder.read(buf, 0, buf.size)
        if (n <= 0) continue
        if (!asrMuted) {
          asrSink(buf.copyOf(n))
        }
      }
    }
  }

  fun setAsrMuted(muted: Boolean) {
    asrMuted = muted
  }

  fun stop() {
    running = false
    recorder.stop()
  }
}
```

### 2) TTS 播放期 AudioAttributes + barge-in 时序

```kotlin
class NativeTtsController(
  private val tts: TextToSpeech,
  private val audioManager: AudioManager,
  private val captureRuntime: AsrCaptureRuntime,
  private val emit: (String, Map<String, Any?>) -> Unit
) {
  fun playTts(requestId: String, text: String, interruptible: Boolean) {
    // 1) mute ASR input first
    captureRuntime.setAsrMuted(true)

    // 2) request focus for speech playback
    val attrs = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_ASSISTANT)
      .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
      .build()
    val focusReq = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
      .setAudioAttributes(attrs)
      .build()
    audioManager.requestAudioFocus(focusReq)

    // 3) configure tts attrs and speak
    tts.setAudioAttributes(attrs)
    emit("ttsStarted", mapOf("requestId" to requestId))
    tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, requestId)

    // 4) if barge-in detector hits:
    // stopTts(); captureRuntime.setAsrMuted(false); emit("bargeInTriggered", ...)
  }

  fun stopTts(reason: String) {
    tts.stop()
    captureRuntime.setAsrMuted(false)
    emit("ttsStopped", mapOf("reason" to reason))
  }
}
```

## iOS 侧设计结论

iOS 需要**同样的设计思想与能力边界**，不是简化版：
- 用 `AVAudioSession` 管理 category/mode、interruption、route change
- 用 `AVAudioEngine` 保持常驻采集并实现输入门控
- 用 `AVSpeechSynthesizer` 播放 TTS，播放期抑制识别输入
- 在 TTS 期间执行原生 barge-in 检测并触发停播/恢复输入

差异仅在 API 细节，不在外部协议行为。Flutter 看到的命令与事件模型保持一致。

## iOS 实现注意事项清单（中断/路由边界）

1. **AVAudioSession 模式选择**
   - 默认使用 `playAndRecord` + `mode: .voiceChat`（优先 AEC/NS），避免仅 `spokenAudio` 导致采集质量波动。
   - 仅在确有设备兼容问题时允许降级到备选 mode，并通过事件上报。

2. **setActive 时序**
   - 会话初始化时只做一次 `setCategory`，进入会话再 `setActive(true)`。
   - 结束会话或进入后台不可录音状态时执行 `setActive(false, .notifyOthersOnDeactivation)`，避免与系统音频冲突。

3. **Interruption 处理**
   - 监听 `AVAudioSession.interruptionNotification`。
   - `.began` 时立即冻结 TTS 与 ASR 上游投递（采集链路可保持）。
   - `.ended` 后依据 `shouldResume` 恢复到中断前 duplex 状态，而不是无条件恢复。

4. **Route Change 处理**
   - 监听 `AVAudioSession.routeChangeNotification`，区分耳机拔出、蓝牙切换、类别变更。
   - 路由变化时重新评估输入设备与输出端，不重建整个 runtime。
   - 对 Flutter 上报 `audioRouteChanged`，携带 `oldRoute/newRoute/reason`。

5. **AVAudioEngine 常驻采集**
   - 使用 input node tap 常驻采集；ASR 门控只控制“是否投递到 ASR sink”。
   - 禁止通过频繁 `engine.stop()/start()` 切换识别状态，避免首帧丢失与启动抖动。

6. **TTS 与门控联动**
   - `AVSpeechSynthesizer` 播放开始前先 `asrMuted=true`。
   - 播放结束/取消后再恢复 `asrMuted=false`，保证“先停播再恢复识别”顺序。
   - 所有回调（start/finish/cancel/error）都必须产生统一事件，避免 Flutter 状态机悬挂。

7. **Barge-in 判定**
   - 播放期间启用轻量 VAD（能量阈值 + 最小时长 + 冷却窗口），避免键盘/环境噪声误触发。
   - 命中后顺序固定：`stop TTS -> unmute ASR -> emit bargeInTriggered/bargeInCompleted`。

8. **回声与自触发控制**
   - 优先依赖 `.voiceChat` 的系统 AEC/NS。
   - 对播放期采集帧增加保护：短窗口抑制/阈值提升，降低“播报内容被自己识别”的概率。

9. **后台与前台切换**
   - App 进入后台时按产品策略决定是否维持采集；若不允许，保存 runtime 状态快照。
   - 回到前台后按快照恢复，而不是重新走完整初始化流程。

10. **可观测性与排障**
    - 统一上报：`focusState`、`route`、`captureActive`、`asrMuted`、`ttsPlaying`、`lastError`。
    - iOS 原始错误码需映射到统一错误分类，同时保留 `rawCode` 便于定位设备特异问题。

## 目录与模块落位

### Flutter
- `voice-note-client/lib/core/audio/native_audio_gateway.dart`（新增）
- `voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`（改造为协议驱动）
- `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`（接入事件流）

### Android
- `voice-note-client/android/app/src/main/kotlin/.../audio/AudioRuntimeController.kt`
- `.../audio/AsrCaptureRuntime.kt`
- `.../audio/NativeTtsController.kt`
- `.../audio/BargeInDetector.kt`
- `.../audio/FocusRouteManager.kt`
- `.../audio/NativeAudioPlugin.kt`（MethodChannel + EventChannel）

### iOS
- `voice-note-client/ios/Runner/Audio/AudioRuntimeController.swift`
- `.../Audio/AsrCaptureRuntime.swift`
- `.../Audio/NativeTtsController.swift`
- `.../Audio/BargeInDetector.swift`
- `.../Audio/NativeAudioPlugin.swift`

## 备选方案与取舍

### 方案A：继续纯 Flutter 插件拼接（放弃）
- 优点：改动小
- 缺点：时序不可控、平台差异难收敛、无法稳定 barge-in

### 方案B：全量下沉原生（采用）
- 优点：时序与资源生命周期可控，能实现行业级语音对话基础能力
- 缺点：实现复杂度上升，需要双端原生维护

结论：采用方案B。

## 风险与缓解

- 风险：平台行为偏差（Android/iOS）
  - 缓解：统一协议+一致性测试+诊断事件对齐
- 风险：barge-in 误触发
  - 缓解：阈值配置化、冷却窗口、指标闭环
- 风险：会话切换导致状态不同步
  - 缓解：requestId 关联 + 幂等命令 + 状态快照接口
