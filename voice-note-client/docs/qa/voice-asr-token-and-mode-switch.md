# 语音记账：ASR Token 与模式切换问题分析

## 问题现象简述

- 手动模式先正常，切换到自动后无法识别；再切回手动也无法识别。
- 界面出现：「原生音频错误：asr_send_error:The request timed out.」以及「没听清你的账单哦，试试说"买咖啡花了20元"这类句式吧」。
- 退出后再次进入语音记账，后台/日志报「asr token 获取不到」（HTTP POST `/api/v1/asr/token` 超时）。

## 1. ASR Token 何时被使用？（回答：不是每次说话结束都请求）

**结论：不是。** Token 只在「建立 ASR WebSocket 连接」时使用，不会在每次说话结束时请求。

- **获取时机**（仅这两处会发 `POST /api/v1/asr/token`）：
  1. **进入语音页并完成会话初始化**：`startSession()` → `startListening(mode)` → `_startNativeAsrStream()` → `AsrRepository.getToken()` → `native.startAsrStream(token, wsUrl, model)`。
  2. **在语音页内从其他模式切到「自动」**：`switchMode(VoiceInputMode.auto)` → `switchInputMode(auto)` → `native.stopAsrStream()` → `_startNativeAsrStream()` → `getToken()` → `native.startAsrStream(...)`。

- **说话/松手时**：只做 mute/commit/收结果，不再访问 token；连接复用同一条 WebSocket。

- **Token 缓存**：`AsrRepository` 会缓存 token，在未过期（且留有约 30 秒余量）时直接复用，不重复请求后端。见 [asr_token_response.dart](lib/core/network/dto/asr_token_response.dart) 的 `isValid`。

## 2. 前端是否存在 Bug？

**有。** 主要有两点。

### 2.1 切到自动时：先断连再建连，若建连失败会留下「无 ASR 连接」状态

逻辑在 [voice_orchestrator.dart](lib/features/voice/domain/voice_orchestrator.dart) 的 `switchInputMode`：

```dart
await native.switchInputMode(sessionId, mode.name);  // 1）先通知 native 切到 auto
if (mode == VoiceInputMode.auto) {
  await native.stopAsrStream(nativeSessionId);      // 2）断开当前 ASR WebSocket
  await _startNativeAsrStream();                     // 3）getToken() + startAsrStream()
}
```

- 若 `_startNativeAsrStream()` 抛错（例如 `getToken()` 超时 15s），则：
  - 步骤 2 已执行，**旧连接已断开**；
  - 步骤 3 未完成，**新连接未建立**；
  - 但 `_currentInputMode` 已在函数开头被设为 `auto`，UI 已显示为「自动」。
- 结果：当前会话处于「自动模式但无 ASR 连接」的不一致状态，后续无论自动还是再切回手动，都没有可用 WebSocket，容易出现发送超时或「没听清」类提示。

这是典型的前端状态机问题：**在「切到自动」分支里，若重建 ASR 失败，应回滚模式或重试建连，而不是保持 auto 且无连接。**

### 2.2 断开连接时，未完成的 WebSocket 发送可能回调超时并上抛到 UI

- 在 [AsrNativeTransport.swift](ios/Runner/Audio/AsrNativeTransport.swift) 中，`sendJSON` 的 completion 里会把错误报给 Flutter：`onError("asr_send_error:\(error.localizedDescription)")`。
- 若在用户 pushEnd 或切换模式时，我们先调用了 `stopAsrStream()`（即 `disconnect()`），而此前已发出的 `commit` 等发送尚未完成，则：
  - 连接被关闭后，未完成的 send 可能以超时等形式回调；
  - 此时仍会触发 `onError`，从而出现「asr_send_error:The request timed out」。
- 原生层虽有 `disconnecting` 标志，但若在设置 `disconnecting` 之前已排队的 send 仍可能在后端报错。前端若在「已知正在断开」时仍把这类错误当正常错误展示给用户，就会显得像「还在用但超时」。

建议：在已知断开（例如切换模式、结束会话）时，对「asr_send_error」类错误做抑制或降级提示，避免误导用户。

## 3. 后端/网络问题

- 日志中「再次退出进入语音记账」后出现：  
  `Failed to fetch ASR token: TimeoutException: Request timed out`，且 HTTP 日志为 15s 超时。
- 说明 **`POST /api/v1/asr/token` 在 15 秒内未返回**，属于：
  - 后端响应过慢，或
  - 网络/代理/防火墙导致请求无法到达或响应被拉长。
- 「asr token 获取不到」描述的就是这次 token 请求失败，与「每次说话结束是否要访问 token」无关（说话结束不访问 token）。

## 4. 流程小结（便于复现与修码）

| 阶段           | 是否请求 ASR Token | 说明 |
|----------------|--------------------|------|
| 进入语音页     | 是（1 次）         | startSession → startListening → _startNativeAsrStream → getToken + startAsrStream |
| 手动/自动说话 | 否                 | 复用已有 WebSocket，只 mute/commit/收结果 |
| 切到「自动」   | 是（可能 1 次）    | stopAsrStream 后 _startNativeAsrStream → getToken（可能用缓存）+ startAsrStream |
| 切到「手动」   | 否                 | 仅 native.switchInputMode，不断开、不重建 ASR |
| 切到「键盘」   | 否                 | stopListening，断开 ASR，不再发音频 |

## 5. 建议修改（前端）

1. **切到自动时若重建 ASR 失败，要做恢复**  
   - 在 `switchInputMode(VoiceInputMode.auto)` 的 `_startNativeAsrStream()` 外 catch：
     - 要么：不把 `_currentInputMode` 设为 auto（或回滚到上一模式），并提示「切换自动模式失败，请检查网络或稍后重试」；
     - 要么：重试一次 `_startNativeAsrStream()`，再失败再回滚并提示。
   - 确保不会出现「已是 auto 但无 ASR 连接」的状态。

2. **断开 ASR 时抑制「asr_send_error」类误报**  
   - 在 Flutter 层：若当前正在执行「切换模式」或「结束会话」，对来自原生的 `asr_send_error` 不弹出「没听清」或通用错误提示，仅日志记录。
   - 或在原生层：在 `disconnect()` 时更早/更一致地设置 `disconnecting`，并在 send 的 completion 里若 `disconnecting` 则不调用 `onError`。

3. **可选：Token 超时与重试**  
   - 若希望在后端偶发慢响应时更稳，可对 `getToken()` 做有限次重试或稍长的 connectTimeout（需与后端/运维协调），避免一次 15s 超时就导致整次建连失败。这不改变「不是每次说话结束都访问 token」的结论。

## 6. 结论汇总

| 问题 | 结论 |
|------|------|
| 每次说话结束都要访问 ASR token 吗？ | **不要。** 只在建立 ASR 连接时用（进语音页、切到自动）。 |
| 切换模式后无法识别，是前端问题吗？ | **部分是。** 切到自动时若 getToken/建连失败，会留下「auto 但无 ASR」状态，需在失败时回滚或重试。 |
| asr_send_error: The request timed out | 可能来自：① 上述无连接状态下发送；② 断开时未完成发送的回调。建议按上面 2 做抑制或区分。 |
| 再次进入语音页「asr token 获取不到」 | **后端/网络**：本次会话的 token 请求 15s 超时，需查服务端与网络，而非「每次说话都请求 token」导致。 |
