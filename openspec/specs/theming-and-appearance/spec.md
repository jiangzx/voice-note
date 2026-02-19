## Purpose

定义应用的主题与外观体系，包括设计令牌、深色模式支持、主题色自定义、以及统一的加载/空/错误状态组件。

## Requirements

### Requirement: 设计令牌体系
系统 SHALL 使用统一的设计令牌定义间距、圆角、动画时长和字体样式。所有 UI 组件 SHALL 引用设计令牌而非硬编码数值。间距 SHALL 基于 4px 网格系统（xs=4, sm=8, md=12, lg=16, xl=24, xxl=32）。

#### Scenario: 间距令牌应用
- **WHEN** 任何 UI 组件需要设定内边距或外边距
- **THEN** SHALL 使用 `AppSpacing` 常量值，而非硬编码数字

#### Scenario: 圆角令牌应用
- **WHEN** 任何 UI 组件需要圆角
- **THEN** SHALL 使用 `AppRadius` 常量值

#### Scenario: 动画时长令牌应用
- **WHEN** 任何 UI 动画需要设定持续时间
- **THEN** SHALL 使用 `AppDuration` 常量值

### Requirement: 深色模式支持
系统 SHALL 支持浅色模式和深色模式。用户 SHALL 能在以下三种模式间切换：跟随系统、浅色、深色。模式选择 SHALL 持久化到本地存储，App 重启后 SHALL 恢复上次选择。

#### Scenario: 跟随系统模式
- **WHEN** 用户选择"跟随系统"且系统为深色模式
- **THEN** App SHALL 使用深色主题渲染

#### Scenario: 手动切换为深色
- **WHEN** 用户手动选择"深色"模式
- **THEN** App SHALL 立即切换为深色主题，无论系统设置

#### Scenario: 模式持久化
- **WHEN** 用户选择"浅色"模式后关闭 App 并重新打开
- **THEN** App SHALL 以浅色模式启动

#### Scenario: 交易语义色适配深色模式
- **WHEN** App 处于深色模式
- **THEN** 收入/支出/转账的语义色 SHALL 调整为适合深色背景的亮色变体

### Requirement: 主题色自定义
系统 SHALL 提供预设的主题配色方案（不少于 5 种），用户 SHALL 能在设置中选择。选择 SHALL 持久化到本地存储。切换主题色后，App 整体配色方案 SHALL 立即更新。

#### Scenario: 选择新主题色
- **WHEN** 用户在设置中选择"靛蓝"配色方案
- **THEN** App 的 `colorSchemeSeed` SHALL 立即变为靛蓝色，所有基于 Material 3 动态配色的组件 SHALL 相应更新

#### Scenario: 主题色持久化
- **WHEN** 用户选择"橙色"配色方案后重启 App
- **THEN** App SHALL 以橙色配色方案启动

#### Scenario: 默认主题色
- **WHEN** 用户从未更改过主题色
- **THEN** App SHALL 使用 teal 作为默认配色

### Requirement: 统一加载状态
系统 SHALL 在所有数据加载场景使用统一的骨架屏占位组件。骨架屏 SHALL 以脉冲动画形式模拟最终内容的布局结构。

#### Scenario: 首页加载
- **WHEN** 首页数据正在加载
- **THEN** 系统 SHALL 展示骨架屏占位符，形状模拟汇总卡片和交易列表的布局

#### Scenario: 列表加载
- **WHEN** 交易列表数据正在加载
- **THEN** 系统 SHALL 展示骨架屏占位符，模拟日分组列表的布局

### Requirement: 统一空状态
系统 SHALL 在所有无数据场景使用统一风格的空状态组件。空状态 SHALL 包含图标、标题文本，MAY 包含描述文本和操作入口。

#### Scenario: 首页无交易空状态
- **WHEN** 用户首次使用 App 且无交易记录
- **THEN** 系统 SHALL 展示统一空状态组件，包含图标和提示文案

#### Scenario: 筛选无结果空状态
- **WHEN** 当前筛选条件下无匹配交易
- **THEN** 系统 SHALL 展示统一空状态组件，提示无匹配结果

### Requirement: 统一错误状态
系统 SHALL 在所有数据加载失败场景使用统一的错误状态组件。错误状态 SHALL 包含错误图标、错误信息、重试操作入口。

#### Scenario: 数据加载失败
- **WHEN** 任何数据 provider 返回错误
- **THEN** 系统 SHALL 展示统一错误组件，包含错误信息和重试入口

#### Scenario: 重试操作
- **WHEN** 用户在错误状态下触发重试
- **THEN** 系统 SHALL 重新请求数据，展示加载状态
