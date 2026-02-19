# 随口记 (SuiKouJi) — Voice Note 记账助手

随口记是一款以**语音对话为核心交互**的智能记账 App。用户只需“随口一说”，应用就能自动识别语音、理解语义、提取金额/分类等关键信息并落库，同时保留传统手动记账体验。

本仓库包含完整的 **Flutter 客户端** 和 **Spring Boot AI 网关服务端**，支持本地优先（local‑first）、离线可用，以及接入阿里云百炼（DashScope）的 ASR/LLM 能力。

---

## 仓库结构

```text
voice-note/
├── docs/                     # PRD、技术设计、部署/上手文档
│   ├── PRD_随口记_v1.1.md
│   ├── Phase2_语音记账_技术设计.md
│   ├── SETUP_GUIDE.md        # 30 分钟上手指南（推荐先读）
│   └── DEPLOYMENT_GUIDE.md   # 生产部署与运维指南
├── voice-note-client/        # Flutter 客户端 (iOS / Android)
│   ├── lib/
│   ├── pubspec.yaml
│   └── README.md
├── voice-note-server/        # Spring Boot AI 网关 (ASR Token + LLM Router)
│   ├── src/
│   └── README.md
├── deploy/                   # Docker Compose 等部署脚本
└── api-contracts/            # OpenAPI / API 合同（如有）
```

---

## 核心能力概览

- **语音记账**：本地 VAD + 阿里云 ASR + LLM 混合解析，将自然语言转为结构化记账记录  
- **本地优先 (Local‑first)**：即使 Server 或网络不可用，仍可手动记账、浏览历史、查看统计  
- **智能解析与兜底**：客户端本地规则引擎优先，复杂语句再经由 Server 转发至通义千问 (qwen‑turbo / qwen‑plus) 解析  
- **多维统计与预算**：按分类、时间区间做收支统计，支持预算预警（详见 PRD）  
- **隐私与安全**：记账数据本地 SQLite 存储，云端仅用于 AI 能力；语音数据不做长期留存（要求见 PRD）

更多产品细节请参考：`docs/PRD_随口记_v1.1.md`。

---

## 技术栈

- **客户端 (voice-note-client)**
  - Flutter 3.x / Dart 3.x
  - 状态管理：Riverpod (`flutter_riverpod` + `riverpod_annotation`)
  - 本地存储：`drift` + `sqlite3_flutter_libs`
  - 路由：`go_router`
  - 语音能力：`record`（录音）、`vad`（本地语音活动检测）、`audio_session`
  - 大模型/网络：`dio`、`web_socket_channel`
  - 其他：`fl_chart`、`flutter_local_notifications`、`share_plus` 等

- **服务端 (voice-note-server)**
  - Spring Boot 3.x (Kotlin)
  - AI 网关职责：
    - ASR Token Broker：为客户端向 DashScope 申请临时 Token
    - LLM Router：将自然语言记账请求转发至 DashScope LLM，并做降级/限流
  - 统一错误处理、限流、配置外置（`application.yml` / 环境变量）

详细服务端 API 说明见：`voice-note-server/README.md` 与 `api-contracts/voice-note-api.yaml`（如存在）。

---

## 快速开始（本地开发）

> 建议先完整阅读 `docs/SETUP_GUIDE.md`，下面仅给出极简流程摘要。

### 1. 前置条件

- JDK 17+（推荐 21）
- Flutter SDK 3.11+（自带 Dart 3.11+）
- Android Studio / Xcode（按需）
- Git 2.x

环境检查示例：

```bash
java -version      # 17+ / 21+
flutter doctor     # 无严重错误 (❌)
```

### 2. 配置云端 API Key（可选但推荐）

1. 在阿里云开通百炼 (DashScope) 服务并创建 API Key  
2. 在本机 shell 配置环境变量（示例，macOS zsh）：

```bash
echo 'export DASHSCOPE_API_KEY=sk-你的实际API_Key' >> ~/.zshrc
echo 'export API_AUTH_KEY=你的自定义API认证密钥' >> ~/.zshrc
source ~/.zshrc
```

具体步骤、费用说明与验证命令详见：`docs/SETUP_GUIDE.md` 第 2 章。

### 3. 启动后端：voice-note-server

在仓库根目录执行：

```bash
cd voice-note-server

# 使用 Gradle 启动（开发环境）
./gradlew bootRun --args='--spring.profiles.active=dev'
```

默认会监听 `http://localhost:8080`，主要 API：

- `POST /api/v1/asr/token` — 获取 ASR 临时 Token  
- `POST /api/v1/llm/parse-transaction` — 解析自然语言为结构化记账请求  

更多配置与 Docker 运行方式见：`voice-note-server/README.md`。

### 4. 启动客户端：voice-note-client

在新终端中：

```bash
cd voice-note-client

# 获取依赖
flutter pub get

# 运行到指定设备（示例：iOS 模拟器 / Android 模拟器）
flutter run
```

客户端会默认连接 `http://localhost:8080`（具体 baseUrl 见 `api_config.dart`），如果你在其他机器或云上启动了 Server，请对应修改。

---

## 文档导航

- **产品规格书 (PRD)**：`docs/PRD_随口记_v1.1.md`  
  - 产品定位、功能清单、交互规则、边界条件
- **Phase 2 技术设计**：`docs/Phase2_语音记账_技术设计.md`  
  - 语音记账架构、AI 网关职责、DashScope 接入方案
- **开发上手指南**：`docs/SETUP_GUIDE.md`  
  - 从零到本地运行的完整步骤（30 分钟内上手）
- **生产部署指南**：`docs/DEPLOYMENT_GUIDE.md`  
  - Docker Compose、环境变量、安全加固、监控与运维

---

## 生产部署概览

生产推荐架构（详细见 `docs/DEPLOYMENT_GUIDE.md`）：

- Client：发布到 App Store / 各大 Android 应用商店  
- Server：运行在云服务器或容器平台（无状态，可水平扩展），通过 HTTPS 暴露 API  
- AI 能力：由阿里云 DashScope 提供 ASR + LLM 能力  

主要配置项：

- `voice-note-server/src/main/resources/application.yml` / `application-prod.yml`
- 环境变量：`DASHSCOPE_API_KEY`、`API_AUTH_KEY`、`CORS_ALLOWED_ORIGINS` 等