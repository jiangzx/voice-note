## ADDED Requirements

### Requirement: 默认列表排序
交易列表 SHALL 按时间倒序展示（最新在前），先按 date 降序，同一日期内再按 created_at 降序。

#### Scenario: 展示排序
- **WHEN** 查询交易列表
- **THEN** 记录 SHALL 按 date DESC、created_at DESC 排序

### Requirement: 日期筛选
系统 SHALL 支持按日期范围筛选交易。快捷筛选选项 SHALL 包含：今天、本周、本月、本年、自定义日期范围。

#### Scenario: 筛选本月
- **WHEN** 用户选择"本月"筛选
- **THEN** 系统 SHALL 仅返回 date 在当前自然月内的交易

#### Scenario: 自定义日期范围筛选
- **WHEN** 用户选择自定义日期范围 2026-02-01 至 2026-02-15
- **THEN** 系统 SHALL 仅返回 date 在该范围内（含首尾）的交易

### Requirement: 分类筛选
系统 SHALL 支持按一个或多个分类筛选交易。

#### Scenario: 按单个分类筛选
- **WHEN** 用户筛选 category="餐饮"
- **THEN** 系统 SHALL 仅返回 category_id 匹配"餐饮"的交易

### Requirement: 账户筛选
当多账户模式开启时，系统 SHALL 支持按账户筛选交易。当多账户模式关闭时，该筛选项 SHALL NOT 可用。

#### Scenario: 按账户筛选
- **WHEN** 多账户模式已开启且用户筛选 account="微信"
- **THEN** 系统 SHALL 仅返回 account_id 匹配"微信"的交易

### Requirement: 金额范围筛选
系统 SHALL 支持按最小金额和/或最大金额筛选交易。

#### Scenario: 按金额范围筛选
- **WHEN** 用户设置 min_amount=100、max_amount=500
- **THEN** 系统 SHALL 仅返回 amount 在 100 至 500 之间（含边界）的交易

### Requirement: 关键词搜索
系统 SHALL 支持按关键词搜索交易。搜索 SHALL 匹配 description 字段（不区分大小写，部分匹配）。

#### Scenario: 按关键词搜索
- **WHEN** 用户搜索"午饭"
- **THEN** 系统 SHALL 返回 description 包含"午饭"的交易

#### Scenario: 无结果
- **WHEN** 用户搜索的关键词无匹配交易
- **THEN** 系统 SHALL 返回空列表

### Requirement: 类型筛选
系统 SHALL 支持按交易类型筛选（expense、income、transfer）。

#### Scenario: 仅筛选支出
- **WHEN** 用户选择 type="expense" 筛选
- **THEN** 系统 SHALL 仅返回支出类型的交易

### Requirement: 组合筛选
多个筛选条件 SHALL 可通过 AND 逻辑组合使用。

#### Scenario: 日期 + 分类组合筛选
- **WHEN** 用户同时筛选本月 AND category="交通"
- **THEN** 系统 SHALL 仅返回同时满足两个条件的交易

### Requirement: 按日分组汇总
交易列表 SHALL 支持按日期分组，并展示每日小计（当日总收入、当日总支出）。小计仅统计 type=income 和 type=expense 的交易，type=transfer SHALL NOT 计入。

#### Scenario: 按日分组
- **WHEN** 以列表视图展示交易
- **THEN** 系统 SHALL 按日期分组交易，并展示每日的收入和支出小计（转账不计入）

### Requirement: 首页收支汇总
系统 SHALL 提供指定日期范围内的收支汇总查询，返回总收入和总支出。计算规则：仅统计 is_draft=false 的交易；type=transfer 的交易 SHALL NOT 计入收入或支出汇总（转账不是真实收支）。

#### Scenario: 今日收支汇总
- **WHEN** 查询今日的收支汇总
- **THEN** 系统 SHALL 返回：今日总收入=SUM(type=income 的 amount)、今日总支出=SUM(type=expense 的 amount)

#### Scenario: 本月收支汇总
- **WHEN** 查询本月的收支汇总
- **THEN** 系统 SHALL 返回当前自然月的总收入和总支出

#### Scenario: 转账不计入收支汇总
- **WHEN** 今日有支出=100、收入=200、转入=500
- **THEN** 今日收支汇总 SHALL 为：总收入=200、总支出=100（转入不计入）

### Requirement: 最近交易查询
系统 SHALL 支持查询最近 N 条交易记录（默认 N=5），按 date DESC、created_at DESC 排序。

#### Scenario: 首页最近 5 条
- **WHEN** 查询最近交易记录（N=5）
- **THEN** 系统 SHALL 返回最多 5 条最新交易，包含所有类型（expense、income、transfer）
