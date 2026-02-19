## ADDED Requirements

### Requirement: 语音输入设置
设置 SHALL 提供语音输入相关配置项。SHALL 包含：默认输入模式（自动模式 / 按住说话 / 键盘输入，默认为自动模式）。配置变更 SHALL 立即持久化。

#### Scenario: 展示当前默认输入模式
- **WHEN** 用户进入设置且默认输入模式为"自动模式"
- **THEN** "自动模式"选项 SHALL 有选中标识

#### Scenario: 切换默认输入模式
- **WHEN** 用户将默认输入模式从"自动模式"改为"按住说话"
- **THEN** 系统 SHALL 持久化新设置，下次进入语音记账页 SHALL 以"按住说话"模式启动

### Requirement: Server 连接设置
设置 SHALL 在高级设置区域提供 Server 地址配置入口。SHALL 展示当前 Server 地址。用户 SHALL 可修改 Server 地址。修改后 SHALL 验证连接可达性并持久化。

#### Scenario: 展示当前 Server 地址
- **WHEN** 用户进入高级设置
- **THEN** 系统 SHALL 展示当前配置的 Server 地址

#### Scenario: 修改 Server 地址
- **WHEN** 用户输入新的 Server 地址并确认
- **THEN** 系统 SHALL 尝试连接新地址的健康检查端点，成功后 SHALL 持久化新地址

#### Scenario: Server 地址无效
- **WHEN** 用户输入的 Server 地址无法连通
- **THEN** 系统 SHALL 展示连接失败提示，SHALL NOT 保存无效地址

### Requirement: Server URL 测试对话框
设置中的 Server 地址编辑 SHALL 使用专用对话框组件。对话框 SHALL 包含 URL 输入框和"测试连接"按钮。测试 SHALL 调用 Server 健康检查端点并实时展示状态（测试中/成功/失败）。成功后"保存"按钮 SHALL 可用。

#### Scenario: 测试连接成功
- **WHEN** 用户输入有效 Server 地址并点击"测试连接"
- **THEN** 系统 SHALL 调用健康检查端点，成功后展示绿色成功状态，"保存"按钮 SHALL 启用

#### Scenario: 测试连接失败
- **WHEN** 用户输入无效 Server 地址并点击"测试连接"
- **THEN** 系统 SHALL 展示红色失败状态和错误信息，"保存"按钮 SHALL 保持禁用
