## ADDED Requirements

### Requirement: 首页收支汇总展示
系统 SHALL 在首页展示当前自然月的收支汇总信息，包含：本月总收入、本月总支出。汇总数据 SHALL 来自 `summaryProvider`，转账类型交易 SHALL NOT 计入。

#### Scenario: 展示本月收支汇总
- **WHEN** 用户进入首页
- **THEN** 系统 SHALL 展示本月的总收入和总支出金额

#### Scenario: 无交易时展示零值
- **WHEN** 当前月无任何交易记录
- **THEN** 系统 SHALL 展示总收入=0、总支出=0

#### Scenario: 汇总排除转账
- **WHEN** 当前月有支出=100、收入=200、转账=500
- **THEN** 汇总 SHALL 展示总收入=200、总支出=100

### Requirement: 首页最近交易列表
系统 SHALL 在首页展示最近 5 条交易记录，按 date DESC、created_at DESC 排序。每条记录 SHALL 展示：分类名称/图标、金额（支出显示负号前缀、收入无前缀、转账标注方向）、日期。若 description 非空则展示 description，否则展示分类名称。

#### Scenario: 展示最近交易
- **WHEN** 用户进入首页且存在交易记录
- **THEN** 系统 SHALL 展示最多 5 条最近交易，每条包含分类信息、金额和日期

#### Scenario: 无交易时展示空状态
- **WHEN** 用户首次使用 App 且无交易记录
- **THEN** 系统 SHALL 展示空状态提示

#### Scenario: 支出金额标注
- **WHEN** 最近交易列表中包含一笔支出 amount=35
- **THEN** 该交易金额 SHALL 展示为 "-35" 或等效负数标识

#### Scenario: 描述回退显示
- **WHEN** 某笔交易 description=null
- **THEN** 系统 SHALL 展示该交易的分类名称作为替代

### Requirement: 快速记账入口
系统 SHALL 在首页提供快速记账入口（FAB），触发后 SHALL 导航至记账流程。

#### Scenario: 触发快速记账
- **WHEN** 用户通过首页快速入口触发记账
- **THEN** 系统 SHALL 导航至记账流程，表单状态 SHALL 为初始状态（类型=支出、金额=0、日期=今天）

### Requirement: 底部导航
系统 SHALL 提供底部导航在首页、明细列表、设置三个一级功能之间切换。导航状态 SHALL 在切换时保持（不重新加载）。

#### Scenario: 导航切换
- **WHEN** 用户从首页切换至明细列表
- **THEN** 系统 SHALL 展示明细列表内容，再切回首页时 SHALL 保持之前的滚动位置

#### Scenario: 默认展示首页
- **WHEN** App 冷启动
- **THEN** 系统 SHALL 默认展示首页
