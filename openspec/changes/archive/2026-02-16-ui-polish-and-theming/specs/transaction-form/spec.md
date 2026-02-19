## MODIFIED Requirements

### Requirement: 转账专属字段
当交易类型为转账时，系统 SHALL 展示转账方向选择（转入/转出）和可选的对方信息输入。对方信息的文本输入控制器 SHALL 在组件生命周期内正确管理（创建于 initState，释放于 dispose），SHALL NOT 在 build 方法中重复创建。

#### Scenario: 选择转出方向
- **WHEN** 类型为转账且用户选择"转出"
- **THEN** `TransactionForm` 的 transferDirection SHALL 为 outbound

#### Scenario: 输入对方信息
- **WHEN** 类型为转账且用户输入对方信息"小明"
- **THEN** `TransactionForm` 的 counterparty SHALL 更新为"小明"

#### Scenario: 对方信息可选
- **WHEN** 类型为转账且用户不输入对方信息
- **THEN** counterparty SHALL 为 null

#### Scenario: 控制器生命周期
- **WHEN** 转账字段组件从 Widget 树中移除
- **THEN** 文本输入控制器 SHALL 被正确释放，不产生内存泄漏

### Requirement: 金额数字键盘输入
系统 SHALL 提供自定义数字键盘（0-9、小数点、退格）用于金额输入。金额 SHALL 以字符串形式管理，仅在保存时转为数值。限制：最多 2 位小数，最大值 99999999.99。键盘按键列表 SHALL 为静态常量，SHALL NOT 在每次 build 时重新创建。

#### Scenario: 输入整数金额
- **WHEN** 用户依次输入 3、5
- **THEN** 金额显示 SHALL 为 "35"

#### Scenario: 输入小数金额
- **WHEN** 用户依次输入 1、2、.、5
- **THEN** 金额显示 SHALL 为 "12.5"

#### Scenario: 小数位数限制
- **WHEN** 金额已为 "12.55" 且用户尝试输入更多数字
- **THEN** 系统 SHALL 忽略该输入，金额保持 "12.55"

#### Scenario: 退格操作
- **WHEN** 金额为 "35" 且用户触发退格
- **THEN** 金额 SHALL 变为 "3"

#### Scenario: 前导零处理
- **WHEN** 金额为 "0" 且用户输入 5
- **THEN** 金额 SHALL 变为 "5"（不显示为 "05"）

#### Scenario: 空金额展示
- **WHEN** 表单初始化或金额被完全退格
- **THEN** 金额显示 SHALL 为 "0"

## ADDED Requirements

### Requirement: 表单设计令牌应用
记账流程的所有 UI 组件 SHALL 使用设计令牌定义的间距、圆角值，替代硬编码数值。

#### Scenario: 间距统一
- **WHEN** 记账流程渲染
- **THEN** 所有组件间距 SHALL 引用 `AppSpacing` 常量

### Requirement: 金额数值变化动画
金额显示区域 SHALL 在数值变化时应用平滑的样式过渡动画。

#### Scenario: 输入数字后动画过渡
- **WHEN** 用户输入数字导致金额变化
- **THEN** 金额文本 SHALL 以平滑动画过渡到新样式
