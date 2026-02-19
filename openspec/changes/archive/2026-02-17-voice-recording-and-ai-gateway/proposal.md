## Why

随口记 App 的核心价值主张是「随口一说，账目清楚」，但当前 Phase 1 仅实现了手动记账。语音记账是产品差异化的关键能力（PRD P2 里程碑），也是付费订阅的核心卖点。为支撑语音 + AI 能力的安全、可控接入，需同步引入后端 AI 网关（voice-note-server），避免客户端直连云端 LLM/ASR 导致的 API Key 泄露、成本不可控等风险。

## What Changes

- 新增 `voice-note-server`（Spring Boot + Kotlin）作为 AI 网关层，负责 ASR 临时凭证发放和 LLM 请求代理
- 客户端新增语音记账模块：本地 VAD 检测 → ASR 实时识别 → 本地规则引擎 + LLM 智能解析 → 确认卡片交互
- 客户端新增 HTTP 网络层（dio），对接 voice-note-server API
- 新增 `api-contracts/` 目录存放 OpenAPI 3.0 客户端-服务端 API 契约
- 客户端新增语音交互 UI：四态状态机（待机→监听→识别→确认）、声波动画、对话气泡、确认卡片
- 客户端新增本地 NLP 规则引擎（关键词→分类映射、金额/日期正则提取）

## Capabilities

### New Capabilities

- `ai-gateway-asr`: AI 网关 ASR Token Broker —— 服务端生成 DashScope 临时凭证供客户端直连 ASR WebSocket，包含限流与配额管理
- `ai-gateway-llm`: AI 网关 LLM 代理 —— 服务端封装 LLM 调用（Prompt 管理、模型降级路由 qwen-turbo→qwen-plus）、结构化交易数据返回
- `voice-recording`: 客户端语音采集与识别 —— 麦克风音频流采集、本地 VAD（Silero）语音活动检测、ASR Token 获取与 DashScope WebSocket 直连、四态状态机管理
- `local-nlp-engine`: 客户端本地 NLP 规则引擎 —— 关键词→分类映射、金额/日期正则提取、离线可用的基础解析能力
- `voice-interaction-ui`: 语音记账交互界面 —— 语音状态动画（脉冲/声波/思考/打勾）、对话气泡、确认卡片（各字段可编辑）、模式切换（自动/按住/键盘）
- `client-network-layer`: 客户端网络层 —— HTTP 客户端（dio）封装、Server 连接配置、请求拦截器、错误处理

### Modified Capabilities

- `home-screen`: 首页新增大号语音记账 FAB 入口，跳转语音记账页
- `settings-screen`: 设置页新增语音相关配置项（默认输入模式、Server 地址配置）

## Impact

- **新增模块**：voice-note-server（Kotlin/Spring Boot 全新项目）、客户端 `features/voice/` 和 `core/network/`
- **新增依赖**：Server 侧（Spring Boot, WebFlux, Bucket4j）；客户端侧（dio, vad, web_socket_channel, record/flutter_sound）
- **API**：新增 2 个 REST 端点（ASR Token、LLM 解析），定义于 `api-contracts/voice-note-api.yaml`
- **部署**：新增 Server Docker 容器、需要阿里云 ECS + DashScope API Key
- **架构约束**：local-first 原则不变 —— Server 故障时手动记账完全不受影响，仅语音功能降级
