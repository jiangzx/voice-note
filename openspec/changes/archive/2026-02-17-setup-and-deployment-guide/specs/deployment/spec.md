## ADDED Requirements

### Requirement: Server 环境配置
系统 SHALL 通过 Spring profiles 管理多环境配置。SHALL 支持 dev（开发）、prod（生产）、test（测试）三个 profile。所有敏感信息（API Key）SHALL 通过环境变量注入，不得硬编码。

#### Scenario: 开发环境启动
- **WHEN** 以 dev profile 启动 Server
- **THEN** 系统 SHALL 启用 TRACE 级日志、完整健康检查详情

#### Scenario: 生产环境启动
- **WHEN** 以 prod profile 启动 Server
- **THEN** 系统 SHALL 启用 INFO 级日志、隐藏健康检查详情、缩短 ASR Token TTL 至 120s

#### Scenario: API Key 缺失
- **WHEN** 未设置 DASHSCOPE_API_KEY 环境变量
- **THEN** Server SHALL 启动失败并输出明确错误提示

### Requirement: Client Server 地址配置
Client SHALL 支持运行时修改 Server 基础地址。默认地址 SHALL 通过 `_defaultBaseUrl` 常量定义。用户修改的地址 SHALL 持久化到 SharedPreferences。发布生产版本前 SHALL 将默认地址更新为生产域名。

#### Scenario: 默认开发地址
- **WHEN** App 首次安装且未修改 Server 地址
- **THEN** Client SHALL 使用 `http://localhost:8080` 作为默认地址（开发版本）

#### Scenario: 生产默认地址
- **WHEN** 发布生产版本
- **THEN** `_defaultBaseUrl` SHALL 更新为 `https://api.suikouji.com`（或实际生产域名）

### Requirement: Docker 容器化部署
Server SHALL 提供 Dockerfile 支持容器化部署。Docker 镜像 SHALL 基于 JRE Alpine（最小化镜像体积）。SHALL 支持通过环境变量传入所有可配置参数。SHALL 内置健康检查端点。

#### Scenario: Docker 构建与运行
- **WHEN** 执行 `docker build` + `docker run`
- **THEN** Server SHALL 正常启动并通过 `/actuator/health` 响应

#### Scenario: Docker Compose 部署
- **WHEN** 执行 `docker compose up`
- **THEN** Server SHALL 通过 compose 配置的环境变量和 profile 正确初始化

### Requirement: 安全配置
生产部署 SHALL 满足以下安全要求：HTTPS 加密传输、API Key 环境变量注入、IP 限流保护、ASR Token 短有效期（≤120s）。

#### Scenario: HTTPS 强制
- **WHEN** 部署到生产环境
- **THEN** 所有 Client-Server 通信 SHALL 通过 HTTPS；HTTP 请求 SHALL 被重定向到 HTTPS
