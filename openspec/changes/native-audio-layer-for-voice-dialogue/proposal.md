## Why

当前语音链路由 Flutter 侧插件直接编排，导致三个核心问题反复出现：PTT 与自动模式边界不稳定、TTS 播放与 ASR 采集互相干扰、以及不同设备上音频路由行为不一致。结果是用户体验出现“该听不该听时都在听”“TTS 不出声”或“识别精度波动大”等问题，无法达到行业级语音对话体验。

为满足“ASR 长期开启 + TTS 可稳定播放 + 支持 barge-in”的目标，需要把关键音频控制下沉到 Android 原生音频层，Flutter 只保留业务编排与状态渲染，从架构层面消除插件级 workaround 的不确定性。

## What Changes

- 新增原生音频运行时层：统一管理麦克风采集、ASR 输入流、TTS 播放、AudioFocus 与路由策略
- 将 ASR 改为“常驻采集 + 可控 mute/unmute”模型，避免频繁启停麦克风
- 定义 TTS 播放期间的采集抑制策略：保证播放稳定且 ASR 不污染输出
- 实现 barge-in：TTS 播放中检测用户语音后快速中断 TTS，并恢复 ASR 有效输入
- 建立 Flutter ↔ Android MethodChannel 协议：命令、状态、错误、时序事件统一上报
- 保留 Flutter 侧语义编排（会话状态机、NLP 调用、UI），移除对底层音频策略的直接控制

## Capabilities

### New Capabilities

- `native-audio-runtime`: 原生音频会话、路由、焦点与设备差异处理
- `voice-duplex-control`: ASR 常驻采集下的输入抑制与输出播放协同控制
- `voice-barge-in-control`: TTS 播放期间的用户打断检测与切换机制

### Modified Capabilities

- `voice-orchestration`: Flutter 编排层从“直接控制音频”调整为“通过协议驱动原生音频运行时”
- `tts-voice-feedback`: TTS 生命周期与状态回传改为原生统一管理
- `voice-recording`: 录音生命周期改为常驻流模型，模式切换只变更控制状态

## Impact

- `voice-note-client/android/`：新增原生音频控制模块（AudioManager/AudioFocus/Recorder/TTS/路由）
- `voice-note-client/lib/features/voice/`：新增平台通道适配层，调整编排器调用链
- `voice-note-client/lib/core/audio/`：从配置型服务升级为协议驱动的音频控制门面
- iOS 侧需提供能力对等实现（AVAudioSession/AVAudioEngine），但允许实现细节差异
- 不涉及服务端 API 变更，不涉及数据库结构变更
