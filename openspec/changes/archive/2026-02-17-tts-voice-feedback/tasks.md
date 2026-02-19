## Tasks

### Task 1: 添加 flutter_tts 依赖并创建 TtsService
**Spec**: tts-voice-feedback  
**Scope**: 新增 `flutter_tts` 依赖、创建 `core/tts/tts_service.dart` 和 `core/tts/tts_templates.dart`

**Subtasks**:
- [ ] 1.1 在 `pubspec.yaml` 添加 `flutter_tts` 依赖
- [ ] 1.2 创建 `TtsService` 类：
  - 初始化系统 TTS 引擎（`setLanguage("zh-CN")`）
  - `Future<void> speak(text)` — 播报文本，返回 Future（完成时 resolve）；如 enabled=false 或 available=false 则立即 resolve
  - `stop()` — 停止当前播报
  - `isSpeaking` — 当前是否正在播报
  - `available` — TTS 引擎是否可用
  - `enabled` / `setEnabled(bool)` — 开关状态（SharedPreferences 持久化）
  - `speechRate` / `setSpeechRate(double)` — 语速（SharedPreferences 持久化）
  - 连续 speak 覆盖：新 speak 前自动 stop 旧播报
  - 初始化失败降级：available=false，所有调用静默返回
- [ ] 1.3 创建 `TtsTemplates` 类：
  - `welcome()` → "你好，想记点什么？"
  - `confirm(category, type, amount)` → "识别到{category}{type}{amount}元，确认吗？"
  - `saved()` → "记好了，还有吗？"
  - `timeout()` → "还在吗？30秒后我就先走啦"
  - `sessionEnd(count, total)` → "本次记了{count}笔，共{total}元，拜拜"
- [ ] 1.4 创建 Riverpod provider 注册 TtsService（在 `voice_providers.dart` 或新建 `core/tts/tts_providers.dart`）
- [ ] 1.5 编写 TtsService 单元测试（mock flutter_tts platform channel）
- [ ] 1.6 编写 TtsTemplates 单元测试

### Task 2: VoiceOrchestrator 集成 TTS 播报
**Spec**: voice-orchestration, tts-voice-feedback  
**Scope**: 修改 `VoiceOrchestrator` 和 `VoiceSessionNotifier`，在关键节点插入 TTS 播报

**Subtasks**:
- [ ] 2.1 VoiceOrchestrator 新增 TtsService 可选依赖，添加 `_isTtsSpeaking` 标志
- [ ] 2.2 添加 `_speakWithSuppression(text)` 内部方法：设 `_isTtsSpeaking=true` → `ttsService.speak(text)` → 设 `_isTtsSpeaking=false`（try-finally 确保重置）
- [ ] 2.3 修改 `_onSpeechStart` 回调：当 `_isTtsSpeaking=true` 时直接 return，忽略 VAD 触发
- [ ] 2.4 在 `startListening` 完成后调用欢迎语播报（auto/pushToTalk 模式）
- [ ] 2.5 在 `_parseAndDeliver` 完成后调用确认播报模板
- [ ] 2.6 VoiceSessionNotifier `confirmTransaction` 和 `onContinueRecording` 保存成功后调用保存成功播报
- [ ] 2.7 VoiceSessionNotifier `endSession` 时调用会话汇总播报（若有已保存交易）
- [ ] 2.8 实现超时预警 TTS：在 LISTENING 状态 2分30秒无人声时触发播报
- [ ] 2.9 所有 TTS 调用点 try-catch 降级处理
- [ ] 2.10 更新 VoiceOrchestrator 单元测试（验证 VAD 抑制行为）

### Task 3: 设置页 TTS 配置
**Spec**: settings-screen  
**Scope**: 修改 `settings_screen.dart`，在"语音输入"区域新增 TTS 开关和语速 Slider

**Subtasks**:
- [ ] 3.1 新增 TTS 开关（SwitchListTile），默认关闭
- [ ] 3.2 新增语速调节 Slider（0.5-2.0，步长 0.1，默认 1.0），TTS 关闭时禁用（灰色）
- [ ] 3.3 开关和语速变更时通过 TtsService.setEnabled / setSpeechRate 持久化

### Task 4: 全量测试验证
**Spec**: 全部  
**Scope**: 运行全量客户端测试，确保无回归

**Subtasks**:
- [ ] 4.1 运行 `flutter test` 全量测试
- [ ] 4.2 修复因 TTS 集成引入的测试失败（确保 TtsService 在测试中静默降级）
- [ ] 4.3 运行 `flutter analyze` 确保无 lint 错误
