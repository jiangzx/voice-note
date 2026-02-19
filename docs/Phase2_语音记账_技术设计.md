# Phase 2 技术设计：语音记账 + AI 网关

> 版本：v1.0  
> 日期：2026-02-17  
> 状态：设计稿

---

## 1. 概述

Phase 2 在 Phase 1（纯客户端手动记账）基础上引入 **语音记账** 能力，核心变更：

- 引入 `voice-note-server`（Spring Boot）作为 **AI 网关层**
- 客户端新增语音交互模块（VAD + ASR + 对话流程）
- 客户端新增 HTTP 层对接 Server

**设计原则：**
- **Local-first 不变**：Server 挂了不影响手动记账
- **最小化 Server 职责**：Phase 2 仅做 ASR Token 发放 + LLM 代理
- **配置驱动**：LLM Provider 切换通过配置完成，不改代码

---

## 2. 系统架构

### 2.1 整体拓扑

```
┌────────────────────────────┐
│      Flutter Client        │
│                            │
│  ┌──────┐  ┌──────────┐   │          ┌──────────────────────┐
│  │ VAD  │  │ 本地规则  │   │          │  voice-note-server   │
│  │Silero│  │ 引擎     │   │          │  (Spring Boot 3.5)   │
│  └──┬───┘  └────┬─────┘   │          │                      │
│     │           │          │          │  ┌────────────────┐  │
│     │  ①请求Token │          │   HTTP   │  │ ASR Token      │  │
│     │  ──────────┼──────────┼────────→ │  │ Broker         │  │
│     │  ②拿到Token │          │          │  └────────────────┘  │
│     │  ←─────────┼──────────┼────────  │                      │
│     │           │          │          │  ┌────────────────┐  │
│     │ ③直连ASR   │          │          │  │ LLM Router     │  │
│     └───────────┼──→ 阿里云ASR         │  │ turbo → plus   │  │
│                 │          │          │  └────────────────┘  │
│    ④本地解析失败  │          │   HTTP   │                      │
│    ⑤发送文本     ├──────────┼────────→ │  ┌────────────────┐  │
│    ⑥收到结构化   ←──────────┼────────  │  │ Rate Limiter   │  │
│                 │          │          │  └────────────────┘  │
│  ┌──────────┐   │          │          │                      │
│  │  drift   │   │          │          └──────────┬───────────┘
│  │  SQLite  │   │          │                     │
│  └──────────┘   │          │                     │ HTTPS
│                            │                     ↓
└────────────────────────────┘          ┌──────────────────────┐
                                        │ 阿里云百炼 DashScope  │
                                        │ - ASR Token API      │
                                        │ - LLM Chat API       │
                                        │   (OpenAI兼容)       │
                                        └──────────────────────┘
```

### 2.2 关键架构决策

| 决策 | 方案 | 原因 |
|------|------|------|
| ASR 连接方式 | **Token Broker**（不代理音频流） | 实时音频中转增加延迟（>100ms），DashScope 支持临时 Token（TTL 1-1800s） |
| LLM 连接方式 | **Server 代理** | 请求量小、非实时；需要 Prompt 管理、降级策略、成本追踪 |
| NLP 策略 | **客户端本地规则优先 → Server LLM 兜底** | 本地解析零成本零延迟；LLM 仅处理本地无法解析的复杂输入 |
| LLM API 格式 | **OpenAI 兼容接口** | DashScope 原生支持；未来切换 Provider 零改造 |
| 限流策略 | **IP 维度令牌桶** | Phase 2 无用户体系，IP 限流是最简可行方案 |

---

## 3. Server 模块设计

### 3.1 目录结构

```
voice-note-server/src/main/kotlin/com/suikouji/server/
├── VoiceNoteServerApplication.kt    # Entry point
├── config/
│   ├── DashScopeProperties.kt       # DashScope config (API key, models, URLs)
│   ├── RateLimitProperties.kt       # Rate limit config per endpoint group
│   ├── WebClientConfig.kt           # WebClient bean for DashScope calls
│   └── WebMvcConfig.kt              # Interceptor registration
├── asr/
│   ├── AsrTokenController.kt        # POST /api/v1/asr/token
│   ├── AsrTokenService.kt           # Calls DashScope token API
│   └── AsrTokenResponse.kt          # Response DTO
├── llm/
│   ├── LlmController.kt             # POST /api/v1/llm/parse-transaction
│   ├── LlmService.kt                # Orchestrates parse with fallback
│   ├── LlmParseException.kt         # Domain exception
│   ├── provider/
│   │   ├── LlmProvider.kt           # Interface (abstraction)
│   │   ├── DashScopeLlmProvider.kt  # OpenAI-compatible implementation
│   │   └── LlmProviderConfig.kt     # Bean definitions (primary + fallback)
│   ├── prompt/
│   │   └── PromptManager.kt         # Loads prompt templates from classpath
│   └── dto/
│       ├── TransactionParseRequest.kt
│       └── TransactionParseResponse.kt
├── ratelimit/
│   └── RateLimitInterceptor.kt      # Token-bucket rate limiter (Bucket4j)
└── api/
    ├── GlobalExceptionHandler.kt     # Unified error handling
    └── dto/
        └── ErrorResponse.kt          # Standard error response
```

### 3.2 ASR Token Broker

**流程：**
1. 客户端发送 `POST /api/v1/asr/token`
2. Server 验证限流 → 调用 DashScope `POST /api/v1/tokens?expire_in_seconds=300`
3. 返回临时 Token + ASR WebSocket URL + 模型名
4. 客户端使用 Token 直连 DashScope ASR WebSocket

**DashScope 临时 Token API：**
- 端点：`POST https://dashscope.aliyuncs.com/api/v1/tokens?expire_in_seconds={ttl}`
- 认证：`Authorization: Bearer {永久API Key}`（仅存于 Server）
- 响应：`{"token":"st-****","expires_at":1744080369}`
- Token 有效期：可配置 1-1800 秒，默认 300 秒

### 3.3 LLM 路由与降级

**流程：**
1. 客户端本地规则引擎解析失败 → 发送 `POST /api/v1/llm/parse-transaction`
2. Server 加载 Prompt 模板 + 拼接用户上下文（常用分类、自定义分类等）
3. 调用 primary model（qwen-turbo）
4. 若失败（超时/错误/解析不出 JSON）→ 自动降级到 fallback model（qwen-plus）
5. 返回结构化 `TransactionParseResponse`

**Prompt 管理：**
- Prompt 模板存储在 `resources/prompts/` 目录下
- `PromptManager` 按需加载并缓存
- 支持上下文注入（用户的自定义分类、最近使用分类、账户列表）

**Provider 抽象：**
```kotlin
interface LlmProvider {
    val modelName: String
    suspend fun chatCompletion(systemPrompt: String, userMessage: String): String
}
```
- 当前实现：`DashScopeLlmProvider`（OpenAI 兼容接口）
- 未来扩展：可新增 `OpenAiProvider`、`AnthropicProvider` 等，通过配置切换

### 3.4 限流

- 算法：**令牌桶**（Bucket4j）
- 维度：IP + 端点分组（ASR / LLM 独立限流）
- 默认配额：ASR 30 次/分钟，LLM 60 次/分钟
- 可通过 `application.yml` 调整
- Phase 5 引入用户体系后，升级为 用户维度限流

---

## 4. API 契约

详见 `api-contracts/voice-note-api.yaml`（OpenAPI 3.0）。

核心端点：

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/asr/token` | 生成临时 ASR Token |
| POST | `/api/v1/llm/parse-transaction` | 自然语言 → 结构化交易数据 |
| GET | `/actuator/health` | 健康检查 |

---

## 5. 客户端变更（voice-note-client）

Phase 2 客户端需新增以下模块（后续 change 详细设计）：

### 5.1 新增模块

| 模块 | 说明 |
|------|------|
| `core/network/` | HTTP 客户端（dio）、Server 连接配置、拦截器 |
| `features/voice/` | 语音记账核心功能 |
| `features/voice/data/` | ASR Token 获取、LLM 解析请求 |
| `features/voice/domain/` | 语音状态机、本地规则引擎、对话管理 |
| `features/voice/presentation/` | 语音记账页 UI（动画、确认卡片、对话气泡） |

### 5.2 新增依赖

| 包 | 用途 |
|----|------|
| `dio` | HTTP 客户端 |
| `vad` | Silero VAD（本地语音活动检测） |
| `web_socket_channel` | DashScope ASR WebSocket 连接 |
| `record` 或 `flutter_sound` | 麦克风音频采集 |

### 5.3 数据流

```
用户说话
  ↓
麦克风 → Silero VAD（本地）
  ↓ 检测到人声
Server.getAsrToken() → 拿到临时 Token
  ↓
DashScope ASR WebSocket（直连，用临时 Token）
  ↓ 返回文本
本地规则引擎解析
  ↓ 成功？→ 展示确认卡片
  ↓ 失败？
Server.parseTransaction(text, context) → LLM 解析
  ↓
展示确认卡片 → 用户确认 → 保存到本地 SQLite
```

---

## 6. 部署策略

### 6.1 Phase 2 部署方案

| 组件 | 方案 | 说明 |
|------|------|------|
| Server | **单台 ECS**（阿里云 2C4G） | 足够支撑初期用户量 |
| 容器化 | Docker + docker-compose | 本地开发和部署一致 |
| HTTPS | Nginx 反向代理 + Let's Encrypt | 阿里云免费 SSL 证书 |
| 监控 | Spring Actuator + 阿里云 ARMS | 基础健康检查 + 应用监控 |

### 6.2 成本估算

| 项目 | 月费用 |
|------|--------|
| 阿里云 ECS 2C4G | ~150 元 |
| DashScope ASR（100 用户） | ~12 元 |
| DashScope LLM（100 用户） | ~0.6 元 |
| 域名 + SSL | 0 元（免费） |
| **合计** | **~163 元/月** |

---

## 7. 演进路线

| 阶段 | Server 变更 |
|------|-------------|
| **Phase 2**（当前） | ASR Token Broker + LLM Router + 限流 |
| **Phase 3-4** | 无变更（统计/导出是纯客户端） |
| **Phase 5** | + 用户认证 + 数据同步 + 订阅管理 + 推送 |
| **未来** | + Redis 缓存 + 分布式限流 + 多实例部署 |

---

## 8. 安全考量

| 风险 | 对策 |
|------|------|
| API Key 泄露 | 永久 Key 仅存于 Server 环境变量，客户端只拿临时 Token |
| 刷接口 | IP 维度令牌桶限流，Phase 5 升级为用户维度 |
| 音频窃听 | ASR 使用 WSS（加密 WebSocket），HTTPS 传输 |
| Prompt 注入 | System Prompt 由 Server 管理，用户输入仅作为 user message |
| 异常流量 | Actuator 监控 + 日志告警 |
