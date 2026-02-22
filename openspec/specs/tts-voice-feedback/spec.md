## Purpose

定义 TTS 语音播报服务的系统行为，包括系统原生 TTS 引擎封装、播报内容模板、语速设置和错误降级。

## Requirements

### Requirement: TTS 服务封装
系统 SHALL 提供 TtsService 组件，封装系统原生 TTS 引擎（iOS AVSpeechSynthesizer / Android TTS）。TtsService SHALL 支持中文语音播报。TtsService SHALL 提供 speak(text)（返回 Future，播报完成时 resolve）、stop()、isSpeaking 接口。TtsService 初始化失败 SHALL 降级为静默模式（available=false），SHALL NOT 影响核心记账流程。

#### Scenario: 正常播报
- **WHEN** 调用 TtsService.speak("识别到餐饮支出35元，确认吗？")
- **THEN** 系统 SHALL 使用系统 TTS 引擎朗读文本，朗读完成后 Future SHALL resolve

#### Scenario: 播报被打断
- **WHEN** TTS 正在播报且调用 stop()
- **THEN** 系统 SHALL 立即停止当前播报

#### Scenario: 连续播报覆盖
- **WHEN** TTS 正在播报"记好了，还有吗？"且新调用 speak("识别到...")
- **THEN** 系统 SHALL 先停止当前播报，再开始新的播报

#### Scenario: TTS 引擎不可用
- **WHEN** 设备未安装中文语音包或 TTS 引擎初始化失败
- **THEN** TtsService.available SHALL 为 false，speak() 调用 SHALL 静默返回（Future 立即 resolve，不抛异常）

#### Scenario: TTS 开关关闭
- **WHEN** TTS 开关为关闭状态（enabled=false）且调用 speak()
- **THEN** speak() SHALL 静默返回（Future 立即 resolve），SHALL NOT 调用系统 TTS 引擎

#### Scenario: 语速设置
- **WHEN** 用户设置语速为 1.2x
- **THEN** TtsService SHALL 以 1.2 倍速播报，设置 SHALL 通过 SharedPreferences 持久化

### Requirement: 播报内容模板
系统 SHALL 提供 TtsTemplates 组件管理预定义播报模板。模板 SHALL 支持动态参数插值。

#### Scenario: 欢迎语
- **WHEN** 用户进入语音记账页且 TTS 已启用
- **THEN** 系统 SHALL 播报"你好，想记点什么？"

#### Scenario: 确认播报
- **WHEN** NLP 解析完成，结果为支出/餐饮/35元
- **THEN** 系统 SHALL 播报"识别到餐饮支出35元，确认吗？"

#### Scenario: 保存成功
- **WHEN** 交易保存成功
- **THEN** 系统 SHALL 播报"记好了，还有吗？"

#### Scenario: 超时预警
- **WHEN** LISTENING 状态静默超过 2分30秒（距 3 分钟超时前 30 秒）
- **THEN** 系统 SHALL 播报「还在吗？暂时不用的话我会先休息哦，30秒后自动退出」（当前实现见 TtsTemplates.timeout）

#### Scenario: 会话结束汇总
- **WHEN** 用户退出语音会话，本次已保存 N 笔交易，合计 X 元
- **THEN** 系统 SHALL 播报"本次记了N笔，共X元，拜拜"

### Requirement: TTS 开关
系统 SHALL 提供 TTS 启用/禁用开关。开关状态 SHALL 通过 SharedPreferences 持久化。TTS 默认 SHALL 为关闭状态。TTS 关闭时所有 speak() 调用 SHALL 静默跳过。

#### Scenario: TTS 关闭
- **WHEN** TTS 开关为关闭状态
- **THEN** 所有播报请求 SHALL 被静默跳过，语音管线正常运行

#### Scenario: TTS 开启
- **WHEN** 用户在设置中开启 TTS
- **THEN** 后续语音会话 SHALL 在关键节点自动播报
