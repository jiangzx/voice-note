## Context

当前语音记账流程为：语音输入 → ASR 转文字 → NLP 解析 → 屏幕展示确认卡片。用户必须看屏幕才能确认结果。TTS 引入后，流程变为：语音输入 → 转文字 → 解析 → **语音播报结果** → 用户语音确认 → 保存。

系统原生 TTS 引擎（iOS：AVSpeechSynthesizer，Android：Android TTS）支持中文，零成本、离线可用。

## Goals / Non-Goals

**Goals:**
- 封装统一的 TTS 服务，支持中文语音播报
- 在语音记账关键节点自动播报
- TTS 播报时与 ASR 录音协调（避免 TTS 声音被 ASR 误识别）
- 用户可在设置中开关 TTS、调节语速
- TTS 错误不影响核心记账流程（降级为静默）

**Non-Goals:**
- 自定义 TTS 音色/声音（使用系统默认）
- 云端 TTS 服务集成（零成本原则）
- 多语言 TTS（仅中文）
- 唤醒词/持续对话（不是语音助手，保持简单）

## Decisions

### D1: TTS 库选型

**决定**：使用 `flutter_tts` 包。

**替代方案**：
- 直接调用平台原生 API（需分平台维护 MethodChannel）
- 云端 TTS（如百炼 TTS API）：增加延迟和成本

**理由**：`flutter_tts` 跨平台封装了系统原生 TTS，零成本、低延迟、离线可用，是 Flutter TTS 的事实标准库。

### D2: TTS 与 ASR 协调

**决定**：TTS 播报时，VoiceOrchestrator 通过内部标志 `_isTtsSpeaking` 抑制 VAD 事件处理（忽略 VAD 触发的语音检测），播报完成后恢复 VAD 事件响应。AudioCapture 保持运行，不 stop/restart（避免重启延迟）。

**替代方案**：
- 停止 AudioCapture → TTS → 重新 start AudioCapture：可行但有重启延迟（~200ms），且需重新初始化 VAD 上下文
- 不做任何协调：TTS 声音会被 VAD 误判为人声，可能触发 ASR 连接
- AEC（回声消除）：移动端 AEC 效果不稳定

**理由**：VAD 事件抑制是最轻量的方案。AudioCapture 持续运行，仅在逻辑层忽略 VAD 的 speechStart 事件。播报时间短（1-3秒），不存在长时间 VAD 静默的问题。TTS 播报期间 ASR 不会被连接（因为 VAD speechStart 被忽略），所以不会出现 TTS 声音被送入 ASR 的问题。

### D3: 播报内容模板

**决定**：使用预定义模板 + 动态插值。

```dart
enum TtsTemplate {
  welcome,       // "你好，想记点什么？"
  confirm,       // "识别到{category}{type}{amount}元，确认吗？"
  saved,         // "记好了，还有吗？"
  timeout,       // "还在吗？30秒后我就先走啦"
  sessionEnd,    // "本次记了{count}笔，共{total}元，拜拜"
}
```

**理由**：模板集中管理，便于修改文案和未来国际化。confirm 模板使用"识别到...确认吗？"而非"帮你记了"，因为此时交易尚未保存，仅是解析完成等待确认。

### D4: TTS 开关存储

**决定**：使用 `SharedPreferences` 存储 TTS 启用状态和语速设置。

**理由**：与现有设置存储方式一致（深色模式、主题色等均使用 SharedPreferences）。

### D5: TTS 默认关闭

**决定**：TTS 默认为关闭状态。

**替代方案**：默认开启，首次使用后可关闭。

**理由**：语音播报在安静环境（如办公室）可能造成尴尬。默认关闭让用户主动选择开启，避免打扰。首次使用引导中已有提示，用户知道此功能存在。

## Directory Structure

```
voice-note-client/lib/core/tts/
├── tts_service.dart              # TTS service wrapper
└── tts_templates.dart            # Predefined speech templates
```

## Risks / Trade-offs

- **[音频冲突]** TTS 播报可能与 ASR 录音冲突 → 播报时暂停 VAD/ASR
- **[语音质量]** 系统 TTS 中文发音可能不够自然 → 可接受，零成本优先
- **[可用性]** 部分设备系统 TTS 引擎未安装中文语音包 → 降级为静默，不影响功能
- **[用户偏好]** 部分用户不希望播报 → 提供开关，默认关闭

## Open Questions

- 无
