## Purpose

扩展设置页，新增 TTS 语音播报开关和语速调节设置项。

## Requirements

### Requirement: TTS 播报设置
设置 SHALL 在"语音输入"区域新增 TTS 播报配置项。SHALL 包含：TTS 开关（Switch，默认关闭）和语速调节（Slider，范围 0.5-2.0，步长 0.1，默认 1.0）。语速调节 SHALL 仅在 TTS 开关开启时可用。配置变更 SHALL 立即持久化到 SharedPreferences。

#### Scenario: 展示 TTS 设置
- **WHEN** 用户进入设置页
- **THEN** 系统 SHALL 在"语音输入"区域展示 TTS 开关和语速 Slider

#### Scenario: 开启 TTS
- **WHEN** 用户开启 TTS 开关
- **THEN** 系统 SHALL 持久化 tts_enabled=true，语速 Slider SHALL 变为可用

#### Scenario: 调节语速
- **WHEN** 用户将语速 Slider 拖到 1.5
- **THEN** 系统 SHALL 持久化 tts_speed=1.5，后续播报 SHALL 以 1.5x 速度

#### Scenario: TTS 关闭时语速不可用
- **WHEN** TTS 开关为关闭状态
- **THEN** 语速 Slider SHALL 处于禁用状态（灰色）
