# iOS 语音采集不启动修复方案（对比 Android，不影响 Android）

## 1. Android vs iOS 行为对比

### 1.1 initializeSession

| 项目 | Android | iOS |
|------|--------|-----|
| Capture 启动 | 仅当 `enableNativeCapture == true` 时调用 `captureRuntime?.start()` | 无条件执行 `configureAudioSession()` → `setActive(true)` → `captureRuntime.start()` |
| 失败时返回值 | `mapOf("ok" to false, "error" to "audio_record_init_failed", "message" to ...)` | `["ok": false, "error": "ios_init_failed"]` |
| 失败时事件 | `emitRuntimeError(...)` | `emitRuntimeError(...)` |

结论：**两端失败时都返回 `ok: false`**。Flutter 当前未检查返回值，导致 iOS 初始化失败后仍继续执行。

### 1.2 switchInputMode(mode: "auto")

| 项目 | Android | iOS |
|------|--------|-----|
| 若 capture 未运行 | `try { captureRuntime?.start() } catch { emitRuntimeError(...); /* 不 return */ }` | `try captureRuntime.start() catch { /* 空，不 emit 不 return */ }` |
| 返回值 | 始终 `mapOf("ok" to true, "mode" to mode)` | 始终 `["ok": true, "mode": mode]` |

结论：**Android 在 auto 模式 capture 启动失败时也只 emit 不返回 false**。修复时不能依赖“检查 switchInputMode 返回值并抛错”，否则会改变 Android 行为。应只修复 Flutter 对 **initializeSession** 的检查，以及 **iOS 端** switchInputMode 内失败时的上报（便于排查），返回值仍可改为 `ok: false` 仅用于 iOS 侧一致性，Flutter 不检查 switchInputMode。

### 1.3 getDuplexStatus

| 项目 | Android | iOS |
|------|--------|-----|
| captureActive | `initialized.get()`（init 成功即为 true） | `captureRuntime.isRunning()`（实际是否在录） |

两端语义略有不同，但“init 成功且未 dispose”时均为 true，可用于启动后做一次校验。

---

## 2. 修复原则

- **Flutter**：只对 **initializeSession** 的返回值做检查并抛错；不检查 switchInputMode 返回值（与当前 Android 行为一致）。
- **Android**：不改逻辑，仅可加日志（可选）。
- **iOS**：修复 initializeSession 错误区分与日志；修复 switchInputMode("auto") 下 capture 启动失败时的上报与返回值；可选在 init 成功后打日志便于排查。

---

## 3. 具体修改

### 3.1 Flutter：检查 initializeSession 返回值（不影响 Android）

**文件**：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

**位置**：`_initNativeAudioRuntime` 内，`await native.initializeSession(...)` 之后。

**修改**：  
在调用 `initializeSession` 后读取返回值，若 `ok != true` 则抛出带 error/message 的 `StateError`，并打 debug 日志。Android 已在失败时返回 `ok: false`，此处检查对所有平台统一，不改变 Android 成功路径。

```dart
// 在 _initNativeAudioRuntime 中，替换原来的两行 await：
final initResult = await native.initializeSession(
  sessionId: nativeSessionId,
  mode: mode.name,
  platformConfig: <String, Object?>{
    'enableNativeCapture': true,
  },
);
final ok = initResult['ok'] as bool? ?? false;
if (!ok) {
  final error = initResult['error'] as String? ?? 'unknown_error';
  final message = initResult['message'] as String? ?? error;
  if (kDebugMode) {
    debugPrint('[VoiceInit] initializeSession failed: error=$error message=$message');
  }
  throw StateError('native_audio_init_failed: $error - $message');
}
if (kDebugMode) {
  debugPrint('[VoiceInit] initializeSession ok');
}

await native.switchInputMode(
  sessionId: nativeSessionId,
  mode: mode.name,
);
// 不检查 switchInputMode 返回值，与 Android 行为一致
```

可选：在 `switchInputMode` 之后调用 `getDuplexStatus`，若 `captureActive == false` 则打 debug 日志并抛错，作为双重校验（Android 成功 init 后 captureActive 为 true，不会误伤）。

---

### 3.2 iOS：initializeSession 区分错误并带 message

**文件**：`voice-note-client/ios/Runner/Audio/AudioRuntimeController.swift`

**位置**：`initializeSession` 的 `do { ... } catch { ... }`。

**修改**：  
在 catch 中根据错误类型设置 `errorCode` 和 `errorMessage`，通过 `emitRuntimeError` 上报，并返回 `["ok": false, "error": errorCode, "message": errorMessage]`，便于 Flutter 和日志排查。例如：

- `configureAudioSession()` 或 `setActive` 失败 → 如 `audio_session_config_failed`
- `captureRuntime.start()` 失败 → 如 `capture_start_failed`
- 其它 → `ios_init_failed`

并在关键步骤前后加 `print` 或 os_log（如 `[VoiceInit] configureAudioSession ok`、`[VoiceInit] captureRuntime.start() failed: ...`），便于真机排查。

---

### 3.3 iOS：switchInputMode("auto") 下 capture 启动失败要上报并返回 false

**文件**：`voice-note-client/ios/Runner/Audio/AudioRuntimeController.swift`

**位置**：`switchInputMode` 中 `case "auto":` 分支，`if !captureRuntime.isRunning() { do { try captureRuntime.start() } catch { ... } }`。

**修改**：  
在 catch 中调用 `emitRuntimeError(code: "capture_start_failed", message: "\(error)")`，并 `return ["ok": false, "error": "capture_start_failed", "message": "\(error)", "mode": mode]`。  
这样 iOS 与 Android 在“init 已检查、仅 auto 切换时失败”的场景下行为一致（Android 只 emit 不返回 false，我们不在 Flutter 检查 switchInputMode，故不改变 Android 行为）；iOS 上能拿到明确错误和日志。

---

### 3.4 可选：启动后 getDuplexStatus 校验（双端安全）

**文件**：`voice-note-client/lib/features/voice/domain/voice_orchestrator.dart`

**位置**：`_initNativeAudioRuntime` 中，在 `switchInputMode` 之后。

**逻辑**：  
调用 `native.getDuplexStatus(nativeSessionId)`，若 `captureActive == false` 则 `if (kDebugMode) debugPrint('[VoiceInit] getDuplexStatus: captureActive=false')` 并 `throw StateError('capture_not_active_after_init')`。  
Android 在 init 成功时 `initialized == true`，getDuplexStatus 的 captureActive 为 true，不会误报；iOS 若 init 已抛错则不会走到这里，若 init 成功但 capture 未跑起来则可被此校验发现。

---

### 3.5 可选：Android 仅加日志

**文件**：`voice-note-client/android/app/src/main/kotlin/com/spark/suikouji/audio/AudioRuntimeController.kt`

**位置**：`initializeSession` 中 `captureRuntime?.start()` 成功/失败分支，以及 `switchInputMode` 的 `"auto"` 分支中 `captureRuntime?.start()` 的 catch。

**修改**：  
在成功时打一条 Log.d（如 `"VoiceInit"`，“initializeSession capture started”），在 catch 中打 Log.e（如 “initializeSession capture start failed”, e）。不改变任何控制流或返回值。

---

## 4. 实施顺序建议

1. **Flutter**：对 `initializeSession` 做返回值检查与抛错 + debug 日志（3.1）。
2. **iOS**：initializeSession 错误区分与 message + 日志（3.2），switchInputMode("auto") 失败时 emit 并 return false + 日志（3.3）。
3. **可选**：Flutter 在 init + switchInputMode 后做 getDuplexStatus 校验（3.4）；Android 仅加日志（3.5）。

按上述顺序实施，可修复 iOS 语音采集不启动、状态栏无录音图标的问题，且不改变 Android 现有行为。
