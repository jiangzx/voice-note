# 随口记 (SuiKouJi) — 端到端上手指南

本文档帮助新开发者在 30 分钟内完成从零到本地运行全栈系统。

---

## 目录

1. [前置条件](#1-前置条件)
2. [申请云服务资源](#2-申请云服务资源)
3. [启动 Server（后端）](#3-启动-server后端)
4. [启动 Client（客户端）](#4-启动-client客户端)
5. [验证连通性](#5-验证连通性)
6. [真机调试语音功能](#6-真机调试语音功能)
7. [常见问题](#7-常见问题)

---

## 1. 前置条件

### 开发工具

| 工具 | 最低版本 | 安装指引 |
|------|---------|---------|
| **JDK** | 17+ (推荐 21) | [Eclipse Temurin](https://adoptium.net/) |
| **Flutter SDK** | 3.11+ | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started/install) |
| **Dart SDK** | 3.11+ | 随 Flutter SDK 自带 |
| **Android Studio** 或 **Xcode** | 最新稳定版 | 根据目标平台选择 |
| **Git** | 2.x | `brew install git` (macOS) |

### 验证安装

```bash
# Java
java -version   # 应显示 17+ 或 21+

# Flutter
flutter doctor   # 应无 ❌ 标记（允许 ⚠ 平台工具链）

# Gradle (项目自带 wrapper，无需全局安装)
```

---

## 2. 申请云服务资源

本项目使用阿里云百炼（DashScope）提供 ASR 语音识别和 LLM 大模型能力。

### 2.1 注册阿里云账号

1. 访问 [阿里云官网](https://www.aliyun.com) → 注册/登录
2. 完成实名认证（个人或企业均可）

### 2.2 开通百炼服务

1. 访问 [百炼控制台](https://bailian.console.aliyun.com/)
2. 点击「开通服务」（首次使用有免费额度）
3. 开通以下能力：
   - **通义千问 语音** — ASR 实时语音识别
   - **通义千问 文本** — LLM 文本生成

### 2.3 获取 API Key

1. 在百炼控制台左侧菜单选择「API-KEY 管理」
2. 点击「创建 API-KEY」
3. 复制生成的 Key（格式：`sk-xxxxxxxxxxxxxxxxxxxxxxxx`）
4. **⚠️ 安全提醒**：
   - API Key 拥有您账户的完整 API 调用权限
   - **绝不要**将 Key 提交到 Git 仓库
   - 建议使用子账号的 Key 并限制权限

### 2.4 设置环境变量

将 API Key 写入 Shell 配置文件（永久生效）：

```bash
# macOS / Linux（zsh）
echo 'export DASHSCOPE_API_KEY=sk-你的实际API_Key' >> ~/.zshrc
echo 'export API_AUTH_KEY=你的自定义API认证密钥' >> ~/.zshrc
source ~/.zshrc

# macOS / Linux（bash）
echo 'export DASHSCOPE_API_KEY=sk-你的实际API_Key' >> ~/.bashrc
echo 'export API_AUTH_KEY=你的自定义API认证密钥' >> ~/.bashrc
source ~/.bashrc

# Windows PowerShell
[System.Environment]::SetEnvironmentVariable('DASHSCOPE_API_KEY', 'sk-你的实际API_Key', 'User')
[System.Environment]::SetEnvironmentVariable('API_AUTH_KEY', '你的自定义API认证密钥', 'User')
# 重启终端生效
```

> **说明**：
> - `DASHSCOPE_API_KEY`：百炼平台 API Key，用于调用 ASR 和 LLM 服务（**必填**）
> - `API_AUTH_KEY`：自定义的客户端-服务端认证密钥，用于保护 Server API 接口（生产环境**必填**，开发环境可选）

验证：

```bash
echo $DASHSCOPE_API_KEY
# 应输出 sk-xxx...

echo $API_AUTH_KEY
# 应输出你设置的认证密钥
```

### 2.5 费用说明

| 服务 | 免费额度 | 超出后计价 |
|------|---------|-----------|
| ASR 实时识别 | 新用户免费额度（详见控制台） | 按时长计费 |
| qwen-turbo | 每月有免费调用额度 | 按 Token 计费，极低成本 |
| qwen-plus | 每月有免费调用额度 | 按 Token 计费 |

> 开发调试阶段通常不会超出免费额度。

---

## 3. 启动 Server（后端）

### 3.1 进入 Server 目录

```bash
cd voice-note-server
```

### 3.2 运行 Server

```bash
# 开发模式（含详细日志）
./gradlew bootRun --args='--spring.profiles.active=dev'
```

首次运行会下载依赖（约 2-5 分钟），后续启动约 5 秒。

### 3.3 验证 Server

```bash
# 健康检查（不需要认证）
curl http://localhost:8080/actuator/health
# 预期输出: {"status":"UP"}

# ASR Token 接口（开发模式默认不需要 API Key）
curl -X POST http://localhost:8080/api/v1/asr/token
# 预期输出: {"token":"st-xxx","expiresAt":...,"model":"qwen3-asr-flash-realtime","wsUrl":"..."}

# LLM 解析接口
curl -X POST http://localhost:8080/api/v1/llm/parse-transaction \
  -H 'Content-Type: application/json' \
  -d '{"text":"午饭花了35块"}'
# 预期输出: {"amount":35.0,"category":"餐饮",...}

# ⚠️ 如果启用了 API Key 认证（api-auth.enabled=true），需要添加 X-API-Key header：
curl -X POST http://localhost:8080/api/v1/asr/token \
  -H 'X-API-Key: 你的API_AUTH_KEY'
```

### 3.4 Server 配置一览

主配置文件：`voice-note-server/src/main/resources/application.yml`

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `server.port` | `8080` | HTTP 端口 |
| `dashscope.api-key` | `${DASHSCOPE_API_KEY}` | DashScope API Key（**必填**，通过环境变量） |
| `dashscope.base-url` | `https://dashscope.aliyuncs.com` | DashScope 基础 URL |
| `dashscope.asr.token-ttl-seconds` | `300` | ASR 临时 Token 有效期（秒） |
| `dashscope.asr.model` | `qwen3-asr-flash-realtime` | ASR 模型 |
| `dashscope.llm.primary-model` | `qwen-turbo` | 主 LLM 模型（快速、低成本） |
| `dashscope.llm.fallback-model` | `qwen-plus` | 降级 LLM 模型（更强、成本稍高） |
| `dashscope.llm.max-tokens` | `500` | LLM 最大输出 Token 数 |
| `dashscope.llm.temperature` | `0.1` | LLM 温度（低 = 更稳定的输出） |
| `api-auth.enabled` | `false` | 是否启用 API Key 认证（生产环境应设为 `true`） |
| `api-auth.key` | `${API_AUTH_KEY:}` | 客户端请求 `X-API-Key` header 的验证密钥 |
| `cors.allowed-origins` | `*` | CORS 允许的来源域名，多个用逗号分隔 |
| `rate-limit.asr.tokens-per-minute` | `30` | ASR 接口每分钟限流 |
| `rate-limit.asr.burst-capacity` | `30` | ASR 接口突发容量 |
| `rate-limit.llm.tokens-per-minute` | `60` | LLM 接口每分钟限流 |
| `rate-limit.llm.burst-capacity` | `60` | LLM 接口突发容量 |
| `rate-limit.trusted-proxies` | 无 | 反向代理 IP 白名单（用于正确解析客户端真实 IP） |

### 3.5 运行 Server 测试

```bash
./gradlew test
# 72 个测试应全部通过
```

---

## 4. 启动 Client（客户端）

### 4.1 进入 Client 目录

```bash
cd voice-note-client
```

### 4.2 安装依赖

```bash
flutter pub get

# 如果 .g.dart 生成文件缺失或过期，需要重新生成：
dart run build_runner build --delete-conflicting-outputs
```

### 4.3 运行 Client

```bash
# iOS 模拟器
flutter run -d ios

# Android 模拟器
flutter run -d android

# 指定设备
flutter devices          # 查看可用设备
flutter run -d <device_id>
```

### 4.4 iOS 权限配置

语音记账功能需要麦克风权限。确认 `ios/Runner/Info.plist` 包含以下配置：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来进行语音记账</string>
```

> 如果未配置此项，iOS 上语音功能将无法使用。

### 4.5 配置 Server 地址

**本地开发**：Client 默认连接 `http://localhost:8080`，与本地 Server 直连。

**真机调试**：真机无法访问 `localhost`，需修改为电脑的局域网 IP：

1. 查看电脑 IP：`ifconfig | grep "inet " | grep -v 127.0.0.1`
2. 在 App 中进入「设置」→「高级设置」→「服务器地址」→ 输入 `http://192.168.x.x:8080`
3. 点击「测试连接」→ 显示成功后保存

### 4.6 配置 API Key（可选）

如果 Server 启用了 API Key 认证（`api-auth.enabled=true`），客户端需要配置对应的 Key：

1. 在 App 中进入「设置」→「高级设置」→「API Key」
2. 输入与 Server 端 `API_AUTH_KEY` 一致的密钥
3. 点击「保存」

> 开发模式下 Server 默认不启用 API Key 认证，此步可跳过。

### 4.7 运行 Client 测试

```bash
flutter test
# 518 个测试应全部通过
```

---

## 5. 验证连通性

启动 Server 和 Client 后，按以下步骤验证全链路：

### 5.1 基础连通

1. 打开 App → 进入「设置」→「Server 连接设置」
2. 点击「测试连接」→ 应显示「连接成功」

### 5.2 语音识别链路

1. 首页点击麦克风图标 → 进入语音记账页
2. 对手机说"午饭三十五块"
3. 预期流程：
   - VAD 检测到人声 → 状态切换为「识别中」
   - ASR 返回文字 → NLP 解析为结构化交易
   - 确认卡片显示：金额 ¥35.00、分类「餐饮」
4. 点击确认 → 交易保存成功

### 5.3 键盘模式

1. 语音记账页底部切换到「键盘」模式
2. 输入 "打车28块" → 发送
3. 确认卡片应显示：金额 ¥28.00、分类「交通」

### 5.4 语音播报（TTS）

1. TTS 默认启用，进入语音记账页后会自动播报欢迎语
2. 如需关闭：「设置」→「语音输入」→ 关闭「语音播报」
3. 可调节语速（0.5x ～ 2.0x）
4. 播报内容包括：欢迎提示、识别结果确认、保存成功、超时提醒、会话结束总结

### 5.5 离线模式

1. 断开网络（飞行模式）
2. 语音记账页显示「离线模式」横幅
3. 键盘输入 "买咖啡15" → 应使用本地 NLP 解析成功
4. 恢复网络 → 横幅消失

---

## 6. 真机调试语音功能

> **重要**：语音功能（麦克风采集 + VAD + ASR + TTS）建议始终在 Android/iOS 真机上调试。模拟器存在麦克风权限和音频桥接限制，详见[模拟器限制](#android-模拟器语音功能限制)。

### 6.1 Android 真机准备

#### Step 1：启用开发者选项

1. **设置** → **关于手机** → 连续点击**版本号** 7 次
2. 返回**设置** → 进入**开发者选项** → 开启 **USB 调试**
3. 部分手机（如小米）还需开启 **USB 安装** 和 **USB 调试（安全设置）**

#### Step 2：USB 连接并授权

```bash
# 连接 USB 后检查设备
adb devices
# 预期输出：
# List of devices attached
# XXXXXXXX    device
```

手机上弹出「允许 USB 调试」对话框 → 勾选「始终允许」→ 确认。

如果显示 `unauthorized`，拔插 USB 重试或在手机上撤销所有 USB 调试授权后重新连接。

#### Step 3：确认 Flutter 识别设备

```bash
flutter devices
# 应列出你的物理设备，例如：
# Pixel 7 (mobile) • XXXXXXXX • android-arm64 • Android 14 (API 34)
```

#### Step 4：配置 Server 地址

真机无法访问 `localhost`，需改用电脑的局域网 IP：

```bash
# 查看电脑局域网 IP
ifconfig | grep "inet " | grep -v 127.0.0.1
# 或
ip addr show | grep "inet " | grep -v 127.0.0.1
```

确保 Server 已启动，然后在 App 中配置：
1. **设置** → **高级设置** → **服务器地址** → 输入 `http://192.168.x.x:8080`
2. 点击 **测试连接** → 成功后保存

> **提示**：手机和电脑必须在同一 WiFi 网络下，且防火墙需放行 8080 端口。

### 6.2 iOS 真机准备

#### Step 1：Apple Developer 配置

1. Xcode → **Preferences** → **Accounts** → 添加 Apple ID
2. 在 `ios/Runner.xcworkspace` 中选择 **Runner** Target → **Signing & Capabilities** → 选择你的 Team

#### Step 2：信任开发者证书

首次安装后，手机上进入：**设置** → **通用** → **VPN 与设备管理** → 信任你的开发者证书。

#### Step 3：运行到真机

```bash
flutter run -d <ios-device-id>
# 或打开 Xcode 直接选真机运行
```

### 6.3 运行 App 到真机

```bash
# 先启动 Server
cd voice-note-server
./gradlew bootRun --args='--spring.profiles.active=dev'

# 新终端：运行 Client 到真机
cd voice-note-client
flutter run -d <device_id>
```

首次运行会安装 APK/IPA 到设备，约需 1-2 分钟。

### 6.4 语音链路日志抓取

App 内置了完整的语音链路日志（仅 Debug 模式生效），使用以下 TAG 过滤：

| TAG | 覆盖阶段 |
|-----|---------|
| `[VoiceInit]` | 语音管线初始化、权限申请、服务启动 |
| `[AudioInit]` | Audio Session 配置（playAndRecord 模式） |
| `[AudioInput]` | 麦克风采集（PCM16 chunk 大小、全零检测） |
| `[VADFlow]` | 语音活动检测（speech start / end / misfire） |
| `[ASRFlow]` | ASR WebSocket 连接、数据发送、协议事件 |
| `[TTSFlow]` | TTS 引擎初始化、speak/stop 调用 |
| `[EventDispatch]` | 事件解析（含 Unrecognized 事件诊断） |

#### Android 日志抓取

```bash
# 方法一：实时查看全部语音日志
adb logcat -s flutter | grep -E "\[(VoiceInit|AudioInit|AudioInput|VADFlow|ASRFlow|TTSFlow|EventDispatch)\]"

# 方法二：保存到文件后离线分析
adb logcat -s flutter > voice_debug.log
# Ctrl+C 停止后：
grep -E "\[(VoiceInit|AudioInput|VADFlow|ASRFlow|TTSFlow)\]" voice_debug.log

# 方法三：只看特定阶段
adb logcat -s flutter | grep "ASRFlow"   # 只看 ASR 链路
adb logcat -s flutter | grep "TTSFlow"   # 只看 TTS 链路
adb logcat -s flutter | grep "VADFlow"   # 只看 VAD 链路
```

#### iOS 日志抓取

```bash
# flutter run 的控制台直接输出 debugPrint 日志，无需额外工具
# 或使用 Console.app 连接真机查看 App 日志
```

### 6.5 语音链路验证步骤

按以下顺序逐段验证，确保每一段通过后再测下一段：

#### 阶段 1：TTS 播报（最先触发）

进入语音记账页后，预期日志：
```
[TTSFlow] init: enabled=true, speechRate=0.5
[TTSFlow] speak: '欢迎使用语音记账...'
```

**如果无日志**：检查 TTS 是否在设置中被关闭。
**如果有日志但无声音**：检查手机音量和媒体播放权限。

#### 阶段 2：麦克风采集

预期日志：
```
[AudioInput] Checking mic permission...
[AudioInput] Permission result: true
[AudioInput] Starting stream: PCM16 16000Hz mono, preBuffer=500ms
[AudioInput] Capture started OK
[AudioInput] Chunk #1: 640 bytes, allZero=false, zeroTotal=0
```

**关键指标**：`allZero` 应为 `false`。如果连续出现 `allZero=true`，说明麦克风数据异常。
**如果 Permission result: false**：检查 App 权限设置 → 允许麦克风。

#### 阶段 3：VAD 语音检测

对着麦克风说话后，预期日志：
```
[VADFlow] Speech START
[VADFlow] Real speech START (confirmed)
```

停止说话后：
```
[VADFlow] Speech END
```

**如果无 Speech START**：可能是麦克风数据全零（回到阶段 2 检查），或 VAD 阈值过高。

#### 阶段 4：ASR 识别

VAD 检测到语音后，预期日志：
```
[ASRFlow] Connecting to DashScope...
[ASRFlow] Connected, sending session.update
[EventDispatch] Received: session.created
[EventDispatch] Received: session.updated
[ASRFlow] Sending audio chunk: 640 bytes (#1)
[ASRFlow] Committing audio buffer
[ASRFlow] Sending response.create after commit
[EventDispatch] Received: response.created
```

**如果 Connecting 后无 session.created**：检查网络连通性和 ASR Token 是否有效。
**如果出现 error 事件**：查看完整错误信息判断是 Token 过期还是协议不匹配。

#### 阶段 5：NLP 解析和确认

ASR 返回最终文本后，NLP 将自动解析为结构化交易：
```
[VoiceInit] Final ASR text: '午饭三十五块'
[TTSFlow] speak: '记录午饭三十五块，金额35.00元...'
```

UI 上应显示确认卡片（金额、分类）。

### 6.6 快速排障清单

| 现象 | 先查什么 | 怎么查 |
|------|---------|--------|
| 完全无声（TTS 无播报） | TTS 是否 enabled | `grep TTSFlow` 看 `enabled=` |
| 说话无反应 | 麦克风数据是否正常 | `grep AudioInput` 看 `allZero` |
| VAD 无触发 | 音频是否有效、VAD 是否启动 | `grep VADFlow` 看 Speech START |
| ASR 无结果 | WebSocket 连接是否成功 | `grep ASRFlow` 看 Connected |
| NLP 解析失败 | Server 是否可达 | `curl http://<IP>:8080/actuator/health` |
| 确认卡片不显示 | 完整链路是否走通 | 使用键盘模式输入测试排除语音链路问题 |

---

## 7. 常见问题

### Server 启动失败

**问题**：`DASHSCOPE_API_KEY not set`
**解决**：确保环境变量已设置：`echo $DASHSCOPE_API_KEY`

**问题**：`Port 8080 already in use`
**解决**：`lsof -i :8080` 查看占用进程，或修改 `application.yml` 中的 `server.port`

### Client 连接失败

**问题**：真机无法连接 Server
**解决**：
1. 确认 Server 和手机在同一 WiFi 网络
2. 使用电脑局域网 IP（非 `localhost`）
3. 检查防火墙是否放行 8080 端口

**问题**：`Connection refused`
**解决**：确认 Server 已启动，`curl http://localhost:8080/actuator/health` 返回 UP

### ASR 识别无响应

**问题**：语音输入后无识别结果
**解决**：
1. 确认麦克风权限已授予
2. 检查 Server 日志：`curl -X POST http://localhost:8080/api/v1/asr/token`
3. 若返回 502，可能是 DashScope API Key 无效或未开通 ASR 服务
4. 通过 `adb logcat -s flutter | grep ASRFlow` 查看 ASR 链路日志

### Android 模拟器语音功能限制

**问题**：模拟器上语音功能完全不工作（无 TTS、无 ASR）

**根因**：Android 模拟器（Ranchu）的虚拟麦克风依赖宿主机音频输入。macOS 可能未授予模拟器进程麦克风权限，导致 Audio HAL `pcm_readi` I/O 错误，音频数据全部为零。

**诊断方法**：
```bash
# 检查音频 HAL 错误
adb logcat | grep "pcm_readi\|ranchu"

# 检查 Dart 层语音日志
adb logcat -s flutter | grep -E "\[(VoiceInit|AudioInput|VADFlow|ASRFlow|TTSFlow)\]"

# 关键指标：AudioInput chunk allZero 比例
# 如果 zeroTotal 接近 chunk 总数，说明麦克风数据全部为零
```

**解决方案**：
1. **macOS 麦克风权限**：系统设置 → 隐私与安全性 → 麦克风 → 启用 `qemu-system-aarch64`
2. **使用真机调试**（推荐）：语音功能建议始终在真机上验证
3. **键盘模式绕过**：切换到「键盘」模式可测试 NLP → 确认 → 保存链路，无需麦克风
4. **AVD 音频检查**：确认 AVD 配置中 `hw.audioInput=yes`

### 测试失败

**问题**：`flutter test` 部分测试失败
**解决**：
1. 确保 `flutter pub get` 已执行
2. 尝试 `flutter clean && flutter pub get && flutter test`
3. 如果是 drift 或 riverpod 相关错误（`.g.dart` 文件缺失），运行 `dart run build_runner build --delete-conflicting-outputs`

### iOS 语音权限

**问题**：iOS 上点击麦克风无反应或闪退
**解决**：确认 `ios/Runner/Info.plist` 中包含 `NSMicrophoneUsageDescription` 键值对

### API Key 认证失败

**问题**：请求返回 `401 Unauthorized` / `{"error":"unauthorized","message":"Invalid or missing API key"}`
**解决**：
1. 确认 Server 是否启用了 API Key 认证：检查 `api-auth.enabled` 配置
2. 在客户端「设置」→「API Key」中填入正确的密钥
3. 确保客户端和服务端使用的 Key 一致

### Docker 部署后 LLM/ASR 调用失败

**问题**：Docker 容器中 Server 启动正常，但调用 ASR Token 或 LLM 解析时返回 500 错误，日志中出现 `PKIX path building failed` 或 `certificate_unknown`
**解决**：
1. 这是 Alpine 镜像的 CA 证书问题，确保使用 `eclipse-temurin` 官方镜像（已内置 CA 证书）
2. 如果仍然出现，在 Dockerfile 中添加：`RUN apk add --no-cache ca-certificates`
3. 检查 DashScope API Key 是否有效：在宿主机上测试 `curl https://dashscope.aliyuncs.com/api-ws/v1/realtime`

### 如何排查特定请求的问题

**问题**：某个用户反馈请求失败，如何查找完整的请求链路日志
**解决**：
1. 获取 `X-Request-ID`：每个响应 header 中都包含 `X-Request-ID`（如 `a1b2c3d4`）
2. 在 Server 日志中搜索该 ID：
   ```bash
   # Docker 部署
   docker logs voice-note-server 2>&1 | grep "a1b2c3d4"
   # 裸机部署
   grep "a1b2c3d4" logs/voice-note-server*.log*
   ```
3. 该请求的所有日志（入口、业务处理、外部调用、错误）都会包含相同的关联 ID

### 请求被限流（429 Too Many Requests）

**问题**：正常使用时频繁收到 `429` 错误
**解决**：
1. 如果 Server 在反向代理后面，检查 `rate-limit.trusted-proxies` 是否配置了代理 IP
2. 未配置时，所有请求被识别为同一 IP（代理 IP），容易触发限流
3. 配置方法：`RATE_LIMIT_TRUSTED_PROXIES=代理IP` 或在 `application-prod.yml` 中设置
