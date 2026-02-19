## Purpose

定义设置的系统行为，包括深色模式切换、主题色选择、多账户模式管理、账户管理入口和分类管理入口。

## Requirements

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

### Requirement: 账户管理入口
当多账户模式开启时，系统 SHALL 展示账户管理入口，导航至账户管理功能。当多账户模式关闭时，该入口 SHALL NOT 展示。

#### Scenario: 多账户开启时可见
- **WHEN** 多账户模式已开启
- **THEN** 账户管理入口 SHALL 可见

#### Scenario: 多账户关闭时隐藏
- **WHEN** 多账户模式关闭
- **THEN** 账户管理入口 SHALL NOT 展示

### Requirement: 账户管理
账户管理 SHALL 展示所有活跃账户列表，支持以下操作：
- 创建新账户（名称必填、类型必选）
- 编辑账户名称和类型
- 归档非预设账户（is_preset=false）
- 预设账户（"钱包"）SHALL NOT 可被归档，MAY 可被重命名

#### Scenario: 展示活跃账户列表
- **WHEN** 用户进入账户管理
- **THEN** 系统 SHALL 展示所有 is_archived=false 的账户

#### Scenario: 创建新账户
- **WHEN** 用户创建账户 name="招商银行"、type="bank_card"
- **THEN** 系统 SHALL 通过 `AccountRepository.create` 持久化并刷新列表

#### Scenario: 归档自定义账户
- **WHEN** 用户对非预设账户触发归档操作
- **THEN** 系统 SHALL 将该账户的 is_archived 设为 true 并从列表移除

#### Scenario: 预设账户保护
- **WHEN** 用户尝试归档预设账户"钱包"
- **THEN** 系统 SHALL 拒绝操作

### Requirement: 分类管理入口
系统 SHALL 在设置中展示分类管理入口，导航至分类管理功能。

#### Scenario: 分类管理可达
- **WHEN** 用户进入设置
- **THEN** 分类管理入口 SHALL 始终可见

### Requirement: 分类管理
分类管理 SHALL 支持按类型切换（支出/收入）展示分类列表，并提供以下操作：
- 创建自定义分类（名称必填、类型、图标、颜色）
- 编辑分类属性
- 删除自定义分类（遵循已有条件删除策略：无引用硬删除、有引用软删除）
- 隐藏/显示分类（包括预设分类）
- 拖拽排序（持久化 sort_order）

预设分类（is_preset=true）SHALL NOT 可被删除，MAY 可被隐藏和重排序。

#### Scenario: 展示支出分类列表
- **WHEN** 用户在分类管理中选择"支出"标签
- **THEN** 系统 SHALL 展示所有支出分类（包括已隐藏的），按 sort_order 排序

#### Scenario: 创建自定义分类
- **WHEN** 用户创建分类 name="学习资料"、type="expense"
- **THEN** 系统 SHALL 通过 `CategoryRepository.create` 持久化并刷新列表

#### Scenario: 拖拽重排序
- **WHEN** 用户通过拖拽将"交通"移到"餐饮"前面
- **THEN** 系统 SHALL 调用 `CategoryRepository.reorder` 持久化新的 sort_order

#### Scenario: 隐藏预设分类
- **WHEN** 用户隐藏预设分类"账单"
- **THEN** 系统 SHALL 将 is_hidden 设为 true，该分类在记账流程中 SHALL NOT 出现

#### Scenario: 删除预设分类被拒绝
- **WHEN** 用户尝试删除预设分类
- **THEN** 系统 SHALL 拒绝操作

#### Scenario: 删除有引用的自定义分类
- **WHEN** 用户删除一个有交易引用的自定义分类
- **THEN** 系统 SHALL 执行软删除（is_hidden=true），历史交易 SHALL 保留分类名称

### Requirement: 语音输入设置
设置 SHALL 提供语音输入相关配置项。SHALL 包含：默认输入模式（自动模式 / 按住说话 / 键盘输入，默认为自动模式）。配置变更 SHALL 立即持久化。

#### Scenario: 展示当前默认输入模式
- **WHEN** 用户进入设置且默认输入模式为"自动模式"
- **THEN** "自动模式"选项 SHALL 有选中标识

#### Scenario: 切换默认输入模式
- **WHEN** 用户将默认输入模式从"自动模式"改为"按住说话"
- **THEN** 系统 SHALL 持久化新设置，下次进入语音记账页 SHALL 以"按住说话"模式启动

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

### Requirement: API Key 设置
设置 SHALL 在高级设置区域提供 API Key 配置入口（位于 Server 地址之后）。SHALL 展示当前 Key 的掩码状态（仅显示后 4 位，未设置时显示"未设置"）。用户 SHALL 可输入、保存和清除 API Key。Key SHALL 持久化到 SharedPreferences。保存后 SHALL 实时更新 ApiClient 的请求头（`X-API-Key`）。

#### Scenario: 展示 API Key 状态
- **WHEN** 用户进入高级设置
- **THEN** API Key 入口 SHALL 展示掩码格式（如"••••abcd"）或"未设置"

#### Scenario: 设置 API Key
- **WHEN** 用户输入 API Key 并保存
- **THEN** 系统 SHALL 持久化 Key 到 SharedPreferences，ApiClient SHALL 立即在后续请求中携带 `X-API-Key` header

#### Scenario: 清除 API Key
- **WHEN** 用户点击"清除"
- **THEN** 系统 SHALL 移除已保存的 Key，ApiClient SHALL 不再携带 `X-API-Key` header

### Requirement: Server URL 测试对话框
设置中的 Server 地址编辑 SHALL 使用专用对话框组件。对话框 SHALL 包含 URL 输入框和"测试连接"按钮。测试 SHALL 调用 Server 健康检查端点并实时展示状态（测试中/成功/失败）。成功后"保存"按钮 SHALL 可用。

#### Scenario: 测试连接成功
- **WHEN** 用户输入有效 Server 地址并点击"测试连接"
- **THEN** 系统 SHALL 调用健康检查端点，成功后展示绿色成功状态，"保存"按钮 SHALL 启用

#### Scenario: 测试连接失败
- **WHEN** 用户输入无效 Server 地址并点击"测试连接"
- **THEN** 系统 SHALL 展示红色失败状态和错误信息，"保存"按钮 SHALL 保持禁用

### Requirement: 预算管理入口
设置 SHALL 提供"预算管理"入口，导航至预算概览页。入口 SHALL 位于"分类管理"之后。

> **实际行为说明**：设置页中该入口标签为"预算管理"而非"预算设置"，更准确反映功能范围（包含概览、编辑、删除等完整管理能力）。

#### Scenario: 预算管理可达
- **WHEN** 用户进入设置页
- **THEN** "预算管理"入口 SHALL 可见

#### Scenario: 导航至预算概览
- **WHEN** 用户点击"预算管理"入口
- **THEN** 系统 SHALL 导航至预算概览页

### Requirement: 数据导出入口
设置 SHALL 提供"数据导出"入口，触发后 SHALL 展示导出选项 Sheet。入口 SHALL 位于"预算管理"之后。

#### Scenario: 数据导出可达
- **WHEN** 用户进入设置页
- **THEN** "数据导出"入口 SHALL 可见

#### Scenario: 触发导出
- **WHEN** 用户点击"数据导出"入口
- **THEN** 系统 SHALL 展示导出选项 Bottom Sheet（包含格式选择和筛选条件）
