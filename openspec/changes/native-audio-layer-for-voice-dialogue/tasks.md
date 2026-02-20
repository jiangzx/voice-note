## 1. Flutter 协议接入层

- [ ] 1.1 新增 `NativeAudioGateway`（MethodChannel + EventChannel 封装），实现 `initializeSession`、`disposeSession`、`setAsrMuted`、`playTts`、`stopTts`、`setBargeInConfig`、`getDuplexStatus`、`switchInputMode`、`getLifecycleSnapshot`、`restoreLifecycleSnapshot`。目标文件：`voice-note-client/lib/core/audio/native_audio_gateway.dart`
- [ ] 1.2 新增 Flutter 侧通道 DTO（命令参数、事件载荷、错误对象、状态快照），统一字段命名（`requestId/route/focusState/canAutoResume`）。目标文件：`voice-note-client/lib/core/audio/native_audio_models.dart`
- [ ] 1.3 修改 `VoiceOrchestrator`：移除直接底层音频控制路径，改为通过 `NativeAudioGateway` 驱动会话与 TTS/barge-in。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [ ] 1.4 修改 `VoiceSessionNotifier`：接入原生事件流，驱动 UI 状态（`ttsStarted/Completed`、`bargeInTriggered/Completed`、`audioRouteChanged`、`audioFocusChanged`）。目标文件：`voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`
- [ ] 1.5 Flutter 单元测试：覆盖网关命令参数序列化、事件反序列化、requestId 关联、`canAutoResume` 分支处理。目标文件：`voice-note-client/test/core/audio/native_audio_gateway_test.dart`

## 2. Android 原生运行时实现

- [ ] 2.1 新增 Android 插件入口 `NativeAudioPlugin`，注册 MethodChannel/EventChannel 并路由到 runtime controller。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/NativeAudioPlugin.kt`
- [ ] 2.2 实现 `AudioRuntimeController`：维护单例会话状态机，统一管理 capture/tts/focus/route/barge-in 组件生命周期。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/AudioRuntimeController.kt`
- [ ] 2.3 实现 `AsrCaptureRuntime`：`AudioRecord` 常驻采集 + `asrMuted` 门控投递；禁止通过 stop/start 切换识别段落。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/AsrCaptureRuntime.kt`
- [ ] 2.4 实现 `NativeTtsController`：`AudioAttributes.USAGE_ASSISTANT` + 焦点协同；播放前 mute、结束后 unmute；上报标准事件。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/NativeTtsController.kt`
- [ ] 2.5 实现 `BargeInDetector`：播放期 VAD（阈值/最小时长/冷却窗）；命中后执行“先停播再恢复识别”时序。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/BargeInDetector.kt`
- [ ] 2.6 实现 `FocusRouteManager`：AudioFocus 回调、路由变化回调、`oldRoute/newRoute/reason` 上报。目标文件：`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/FocusRouteManager.kt`
- [ ] 2.7 Android 仪器/单元测试：覆盖门控幂等、barge-in 触发与误触发、焦点中断恢复、标准事件字段完整性。目标文件：`voice-note-client/android/app/src/test/kotlin/com/suikouji/client/audio/AudioRuntimeControllerTest.kt`

## 3. iOS 原生运行时实现

- [ ] 3.1 新增 iOS 插件入口 `NativeAudioPlugin`，桥接 Flutter 命令与事件。目标文件：`voice-note-client/ios/Runner/Audio/NativeAudioPlugin.swift`
- [ ] 3.2 实现 `AudioRuntimeController`：统一管理 `AVAudioSession`、`AVAudioEngine`、`AVSpeechSynthesizer` 生命周期。目标文件：`voice-note-client/ios/Runner/Audio/AudioRuntimeController.swift`
- [ ] 3.3 实现 `AsrCaptureRuntime`：input tap 常驻采集 + 门控投递，不通过频繁 `engine.stop()/start()` 切换识别。目标文件：`voice-note-client/ios/Runner/Audio/AsrCaptureRuntime.swift`
- [ ] 3.4 实现 `NativeTtsController`：播放前后门控联动、TTS 生命周期事件、失败回退恢复。目标文件：`voice-note-client/ios/Runner/Audio/NativeTtsController.swift`
- [ ] 3.5 实现 `BargeInDetector`：播放期语音检测与防误触，输出标准 `bargeInTriggered/bargeInCompleted` 事件。目标文件：`voice-note-client/ios/Runner/Audio/BargeInDetector.swift`
- [ ] 3.6 实现 interruption/route 处理：`canAutoResume` 判定、前后台快照恢复、`audioRouteChanged` 标准字段。目标文件：`voice-note-client/ios/Runner/Audio/FocusRouteManager.swift`
- [ ] 3.7 iOS 单元测试：覆盖 interruption ended 非自动恢复、路由变更中打断、快照恢复一致性。目标文件：`voice-note-client/ios/RunnerTests/AudioRuntimeControllerTests.swift`

## 4. 跨平台协议一致性与观测

- [ ] 4.1 定义并实现统一错误映射（Android/iOS -> 通用错误码 + `rawCode`）。目标文件：`voice-note-client/lib/core/audio/native_audio_models.dart`、`voice-note-client/android/app/src/main/kotlin/com/suikouji/client/audio/ErrorMapper.kt`、`voice-note-client/ios/Runner/Audio/ErrorMapper.swift`
- [ ] 4.2 补充事件载荷一致性校验工具（字段完整性、类型、必填项）。目标文件：`voice-note-client/lib/core/audio/native_audio_event_validator.dart`
- [ ] 4.3 增加埋点：`bargeInLatencyMs`、`falseTriggerCount`、`ttsStopCostMs`、`resumeCostMs`、`focusLossCount`。目标文件：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`
- [ ] 4.4 协议一致性测试：Android/iOS 同场景回放后比较事件序列（顺序与字段）。目标文件：`voice-note-client/test/core/audio/native_audio_protocol_consistency_test.dart`

## 5. 集成验证与回归

- [ ] 5.1 Android 真机验证：自动模式/PTT 模式/键盘模式切换，确认 ASR 常驻采集且无频繁麦克风重启。目标文件：`voice-note-client/docs/qa/native-audio-runtime.md`
- [ ] 5.2 iOS 真机验证：interruption、route change、前后台切换，确认 `canAutoResume` 与快照恢复符合规范。目标文件：`voice-note-client/docs/qa/native-audio-runtime.md`
- [ ] 5.3 E2E 语音对话验证：TTS 播放稳定、播放期不污染 ASR、barge-in 成功率达标。目标文件：`voice-note-client/docs/qa/native-audio-runtime.md`
- [ ] 5.4 回归测试：现有语音记账主流程（识别、确认、纠正、保存）无功能回退。目标文件：`voice-note-client/test/features/voice/`
