## ADDED Requirements

### Requirement: 多账户模式开关
系统 SHALL 在设置中展示多账户模式开关，反映 `multiAccountEnabledProvider` 的当前状态。切换时 SHALL 调用 `AccountRepository.setMultiAccountEnabled` 持久化新状态。

#### Scenario: 展示当前状态
- **WHEN** 用户进入设置且多账户模式关闭
- **THEN** 开关 SHALL 处于关闭状态

#### Scenario: 开启多账户模式
- **WHEN** 用户开启多账户模式
- **THEN** 系统 SHALL 持久化 multi_account_enabled=true，账户管理入口 SHALL 变为可用

#### Scenario: 关闭多账户模式
- **WHEN** 用户关闭多账户模式
- **THEN** 系统 SHALL 持久化 multi_account_enabled=false，账户管理入口 SHALL 隐藏

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
