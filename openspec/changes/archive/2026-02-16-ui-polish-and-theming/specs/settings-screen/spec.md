## ADDED Requirements

### Requirement: 深色模式切换
设置 SHALL 提供深色模式切换入口，支持三种选项：跟随系统、浅色、深色。当前选择 SHALL 有视觉标识。切换后 SHALL 立即生效并持久化。

#### Scenario: 展示当前模式
- **WHEN** 用户进入设置且当前为"跟随系统"模式
- **THEN** "跟随系统"选项 SHALL 有选中标识

#### Scenario: 切换为深色模式
- **WHEN** 用户选择"深色"模式
- **THEN** App SHALL 立即切换为深色主题，设置 SHALL 持久化

#### Scenario: 切换为浅色模式
- **WHEN** 用户选择"浅色"模式
- **THEN** App SHALL 立即切换为浅色主题，设置 SHALL 持久化

### Requirement: 主题色选择
设置 SHALL 提供主题色选择入口，展示所有预设配色方案。当前选中的配色 SHALL 有视觉标识。选择新配色后 SHALL 立即生效并持久化。

#### Scenario: 展示预设配色
- **WHEN** 用户进入主题色选择
- **THEN** 系统 SHALL 展示不少于 5 种预设配色方案

#### Scenario: 选择新配色
- **WHEN** 用户选择"靛蓝"配色
- **THEN** App 配色 SHALL 立即更新为靛蓝色调，设置 SHALL 持久化

#### Scenario: 当前配色标识
- **WHEN** 当前配色为"橙色"
- **THEN** "橙色"选项 SHALL 有选中标识

## MODIFIED Requirements

### Requirement: 多账户模式开关
系统 SHALL 在设置中展示多账户模式开关，反映 `multiAccountEnabledProvider` 的当前状态。切换时 SHALL 调用 `AccountRepository.setMultiAccountEnabled` 持久化新状态。加载时 SHALL 展示统一加载状态。加载失败时 SHALL 展示统一错误组件。所有间距 SHALL 使用设计令牌。

#### Scenario: 展示当前状态
- **WHEN** 用户进入设置且多账户模式关闭
- **THEN** 开关 SHALL 处于关闭状态

#### Scenario: 开启多账户模式
- **WHEN** 用户开启多账户模式
- **THEN** 系统 SHALL 持久化 multi_account_enabled=true，账户管理入口 SHALL 变为可用

#### Scenario: 关闭多账户模式
- **WHEN** 用户关闭多账户模式
- **THEN** 系统 SHALL 持久化 multi_account_enabled=false，账户管理入口 SHALL 隐藏

#### Scenario: 设置加载失败
- **WHEN** 多账户模式数据加载失败
- **THEN** 系统 SHALL 展示统一错误组件并提供重试
