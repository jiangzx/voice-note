## MODIFIED Requirements

### Requirement: 首页收支汇总展示
系统 SHALL 在首页展示当前自然月的收支汇总信息，包含：本月总收入、本月总支出。汇总数据 SHALL 来自 `summaryProvider`，转账类型交易 SHALL NOT 计入。加载时 SHALL 展示骨架屏占位符。加载失败时 SHALL 展示统一错误组件并提供重试。所有间距 SHALL 使用设计令牌。

#### Scenario: 展示本月收支汇总
- **WHEN** 用户进入首页
- **THEN** 系统 SHALL 展示本月的总收入和总支出金额

#### Scenario: 无交易时展示零值
- **WHEN** 当前月无任何交易记录
- **THEN** 系统 SHALL 展示总收入=0、总支出=0

#### Scenario: 汇总排除转账
- **WHEN** 当前月有支出=100、收入=200、转账=500
- **THEN** 汇总 SHALL 展示总收入=200、总支出=100

#### Scenario: 汇总加载中
- **WHEN** 汇总数据正在加载
- **THEN** 系统 SHALL 展示骨架屏占位符

#### Scenario: 汇总加载失败
- **WHEN** 汇总数据加载失败
- **THEN** 系统 SHALL 展示统一错误组件，包含重试入口

### Requirement: 首页最近交易列表
系统 SHALL 在首页展示最近 5 条交易记录，按 date DESC、created_at DESC 排序。每条记录 SHALL 展示：分类名称/图标、金额（支出显示负号前缀、收入无前缀、转账标注方向）、日期。若 description 非空则展示 description，否则展示分类名称。加载时 SHALL 展示骨架屏。无数据时 SHALL 展示统一空状态组件。加载失败时 SHALL 展示统一错误组件。列表数据加载完成时 SHALL 以淡入动画展示。

#### Scenario: 展示最近交易
- **WHEN** 用户进入首页且存在交易记录
- **THEN** 系统 SHALL 展示最多 5 条最近交易，每条包含分类信息、金额和日期

#### Scenario: 无交易时展示空状态
- **WHEN** 用户首次使用 App 且无交易记录
- **THEN** 系统 SHALL 展示统一空状态组件

#### Scenario: 支出金额标注
- **WHEN** 最近交易列表中包含一笔支出 amount=35
- **THEN** 该交易金额 SHALL 展示为 "-35" 或等效负数标识

#### Scenario: 描述回退显示
- **WHEN** 某笔交易 description=null
- **THEN** 系统 SHALL 展示该交易的分类名称作为替代

#### Scenario: 列表入场动画
- **WHEN** 最近交易数据从加载状态变为有数据
- **THEN** 列表 SHALL 以淡入动画展示
