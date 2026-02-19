## Purpose

定义应用的核心数据模型与持久化策略，包括本地优先存储、同步元数据、主键生成和时间戳管理规则。

## Requirements

### Requirement: 本地优先存储
系统 SHALL 使用 SQLite（via drift）作为本地持久化方案。所有数据 MUST 存储在本地，无需网络连接或用户登录。

#### Scenario: 离线数据访问
- **WHEN** 设备无网络连接
- **THEN** 系统 SHALL 正常读写本地 SQLite 数据库，不产生错误

#### Scenario: 首次启动无需登录
- **WHEN** 用户首次打开 App 且未注册或登录
- **THEN** 系统 SHALL 初始化数据库并提供完整的记账功能

### Requirement: 同步元数据字段
每个核心实体（accounts、categories、transactions）SHALL 包含同步元数据字段：updated_at（DATETIME）、sync_status（TEXT，默认 "local"）、remote_id（TEXT，可空）。这些字段为后续云同步（P5）预留，P1 阶段 SHALL NOT 在 UI 中暴露。

#### Scenario: 新记录的同步字段
- **WHEN** 创建一条新的交易记录
- **THEN** sync_status SHALL 设为 "local"，remote_id SHALL 为 null

### Requirement: UUID 主键
所有实体 SHALL 使用 UUID v4 字符串作为主键，通过 uuid 包在本地生成。

#### Scenario: 跨设备唯一 ID
- **WHEN** 两台设备独立创建记录
- **THEN** 两条记录的主键 SHALL NOT 冲突（UUID v4 唯一性保证）

### Requirement: 账户初始余额字段
accounts 表 SHALL 包含 initial_balance 字段（REAL 类型，默认 0.0）。该字段为后续多账户资产管理预留，P1 阶段 SHALL NOT 在 UI 中暴露。

#### Scenario: 新账户默认初始余额
- **WHEN** 创建一个新账户
- **THEN** initial_balance SHALL 默认设为 0.0

### Requirement: 实体关系
- Account 1:N Transaction（每笔交易绑定且仅绑定一个账户）
- Category 1:N Transaction（转账类型可不绑定分类）
- Transaction 1:1 Transaction（通过 linked_transaction_id 可选配对）

#### Scenario: 交易引用账户
- **WHEN** 创建一笔交易
- **THEN** 该交易 SHALL 通过 account_id（外键）引用且仅引用一个账户

#### Scenario: 转账无需分类
- **WHEN** 创建一笔 type="transfer" 的交易
- **THEN** category_id MAY 为 null

### Requirement: 默认币种
所有金额 SHALL 默认使用人民币（CNY）。transactions 表中的 currency 字段 SHALL 存在但 P1 阶段 SHALL NOT 提供用户选择。多币种支持推迟到后续版本。

#### Scenario: 交易金额币种
- **WHEN** 创建一笔交易
- **THEN** currency SHALL 自动设为 "CNY"

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
