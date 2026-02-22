## Purpose

定义首页的系统行为，包括当月收支汇总展示、最近交易列表、快速记账入口和底部导航切换。

## Requirements

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
系统 SHALL 在首页展示最近交易记录，按 date DESC、created_at DESC 排序。首屏 SHALL 加载一页（当前实现为 20 条），支持「加载更多」分页。每条记录 SHALL 展示：分类名称/图标、金额（支出显示负号前缀、收入无前缀、转账标注方向）、日期。若 description 非空则展示 description，否则展示分类名称。加载时 SHALL 展示骨架屏。无数据时 SHALL 展示统一空状态组件。加载失败时 SHALL 展示统一错误组件。列表数据加载完成时 SHALL 以淡入动画展示。

#### Scenario: 展示最近交易
- **WHEN** 用户进入首页且存在交易记录
- **THEN** 系统 SHALL 展示首屏一页最近交易（当前为 20 条），每条包含分类信息、金额和日期

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

### Requirement: 首页预算进度摘要
系统 SHALL 在首页展示当月预算总体使用进度。若无分类设置预算，该区域 SHALL NOT 展示。摘要 SHALL 包含总预算金额、已消费金额、剩余金额和百分比进度条。点击摘要 SHALL 导航至预算概览页。

#### Scenario: 展示总预算进度
- **WHEN** 用户有 3 个分类设置了预算，合计 ¥5000，已消费 ¥3000
- **THEN** 首页 SHALL 展示总预算进度（60%）、已消费 ¥3000、剩余 ¥2000

#### Scenario: 超支状态展示
- **WHEN** 总消费超过总预算
- **THEN** 首页 SHALL 展示超支金额（红色）

#### Scenario: 无预算设置
- **WHEN** 用户未设置任何预算
- **THEN** 首页 SHALL NOT 展示预算摘要区域

### Requirement: 快速记账入口
系统 SHALL 在首页提供语音记账入口（居中悬浮 FAB），触发后 SHALL 导航至语音记账页（LISTENING 状态）。手动记账入口 SHALL 以小号 FAB 展示在语音 FAB 旁边（当前实现为 Shell 层 FAB），触发后 SHALL 导航至记账表单。语音记账 FAB SHALL 在所有底部导航 Tab 页面可见。

> **实际行为说明**：手动记账入口当前以 Shell 层小号 FAB 实现（位于语音 FAB 右侧），而非 AppBar 图标按钮。功能等价，视觉位置不同。

#### Scenario: 触发语音记账
- **WHEN** 用户点击居中语音 FAB
- **THEN** 系统 SHALL 导航至语音记账页，状态 SHALL 为 LISTENING

#### Scenario: 触发手动记账
- **WHEN** 用户点击手动记账入口（当前实现为 Shell 层小号 FAB，位于语音 FAB 旁）
- **THEN** 系统 SHALL 导航至记账流程，表单状态 SHALL 为初始状态

#### Scenario: 语音 FAB 全局可见
- **WHEN** 用户在任意底部 Tab 页面
- **THEN** 语音记账 FAB SHALL 居中悬浮可见

### Requirement: 底部导航
系统 SHALL 提供底部导航在首页、统计、明细列表、设置四个一级功能之间切换。导航状态 SHALL 在切换时保持（不重新加载）。

#### Scenario: 导航切换
- **WHEN** 用户从首页切换至统计页
- **THEN** 系统 SHALL 展示统计页内容，再切回首页时 SHALL 保持之前的滚动位置

#### Scenario: 默认展示首页
- **WHEN** App 冷启动
- **THEN** 系统 SHALL 默认展示首页

#### Scenario: 导航至统计页
- **WHEN** 用户点击底部"统计"Tab
- **THEN** 系统 SHALL 展示统计页
