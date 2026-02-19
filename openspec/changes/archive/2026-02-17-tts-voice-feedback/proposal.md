## Why

语音记账目前是"语音输入 → 文字反馈"的单向模式。用户在开车、做饭等双手不便的场景下，仍需低头看屏幕确认结果。引入 TTS（Text-to-Speech）语音播报，实现"语音输入 → 语音反馈"的全语音交互闭环，大幅提升 hands-free 使用体验。TTS 使用系统原生引擎（零成本、零延迟、离线可用），不依赖云端服务。

## What Changes

- 新增 TTS 服务封装：基于 `flutter_tts` 的统一语音播报接口
- 语音记账流程中关键节点自动播报：
  - 进入语音模式时的欢迎语
  - 识别完成后播报确认询问（如"识别到餐饮支出35元，确认吗？"）
  - 保存成功后的反馈语
  - 超时预警提示
  - 退出时播报会话汇总
- 设置页新增 TTS 开关和语速调节
- TTS 与 ASR 协调：播报时暂停录音，播报完成后恢复

## Capabilities

### New Capabilities
- `tts-voice-feedback`: TTS 语音播报服务、播报内容模板、与语音录制的协调逻辑

### Modified Capabilities
- `voice-orchestration`: VoiceOrchestrator 集成 TTS 播报节点，播报时暂停 VAD/ASR
- `settings-screen`: 新增 TTS 播报开关和语速设置

## Impact

- **客户端新增依赖**：`flutter_tts`（系统原生 TTS 引擎封装）
- **客户端新增模块**：`core/tts/`（TTS 服务）
- **修改模块**：`voice_orchestrator.dart`（集成播报节点）、`voice_session_provider.dart`（触发播报）、`settings_screen.dart`（TTS 设置）
- **服务端**：无变更（纯客户端功能）
- **性能**：TTS 使用系统引擎，零网络开销、零额外内存，播报延迟 <100ms
