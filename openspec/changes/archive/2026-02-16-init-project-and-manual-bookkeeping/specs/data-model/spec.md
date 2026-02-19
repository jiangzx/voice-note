## ADDED Requirements

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
