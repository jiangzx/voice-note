## ADDED Requirements

### Requirement: 预算表
系统 SHALL 包含 budgets 表用于存储分类月度预算。表结构 SHALL 包含以下字段：id（TEXT PRIMARY KEY, UUID v4）、category_id（TEXT NOT NULL, 外键引用 categories）、amount（REAL NOT NULL, 大于零）、year_month（TEXT NOT NULL, 格式 "YYYY-MM"）、created_at（DATETIME）、updated_at（DATETIME）。同一分类同一月份 SHALL 仅有一条预算记录（category_id + year_month 唯一约束）。

#### Scenario: 创建预算记录
- **WHEN** 系统创建一条预算记录 category_id="餐饮ID", amount=2000, year_month="2026-02"
- **THEN** 记录 SHALL 持久化到 budgets 表，id 为自动生成的 UUID v4

#### Scenario: 唯一约束
- **WHEN** 系统尝试为同一分类同一月份创建第二条预算记录
- **THEN** 系统 SHALL 拒绝创建或执行更新（upsert）

### Requirement: 数据库迁移 v1 → v2
系统 SHALL 支持从 schema version 1 平滑迁移到 version 2。迁移 SHALL 仅新增 budgets 表，SHALL NOT 修改或删除现有表。现有数据 SHALL 完整保留。

#### Scenario: 已有用户升级
- **WHEN** schema version 1 的用户升级 App
- **THEN** 系统 SHALL 自动创建 budgets 表，现有 accounts、categories、transactions 数据 SHALL 不受影响

#### Scenario: 新用户安装
- **WHEN** 新用户首次安装 App
- **THEN** 系统 SHALL 创建 schema version 2 的完整数据库，包含 budgets 表

### Requirement: 统计聚合查询
系统 SHALL 提供高效的统计聚合查询能力。聚合 SHALL 在 SQLite 层通过 SQL 完成（非内存聚合）。SHALL 支持的查询类型：按分类汇总（饼图数据）、按时间段每日/每月趋势（折线/柱状图数据）、时间段内收支总额。所有统计和预算相关查询 SHALL 排除 `isDraft=true` 的交易记录。

#### Scenario: 按分类汇总查询
- **WHEN** 系统查询 2026-02 的支出分类汇总
- **THEN** SHALL 返回每个分类的 name、total_amount、百分比，按 total_amount DESC 排序

#### Scenario: 每日趋势查询
- **WHEN** 系统查询 2026-02 的每日趋势
- **THEN** SHALL 返回每天的 date、income_total、expense_total

#### Scenario: 空结果集
- **WHEN** 查询时间段无交易
- **THEN** SHALL 返回空列表（非 null）

#### Scenario: 排除草稿交易
- **WHEN** 时间段内有 3 笔正式交易和 1 笔草稿交易（isDraft=true）
- **THEN** 统计结果 SHALL 仅包含 3 笔正式交易，草稿 SHALL NOT 计入
