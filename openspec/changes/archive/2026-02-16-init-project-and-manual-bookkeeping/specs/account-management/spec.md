## ADDED Requirements

### Requirement: 默认账户初始化
系统 SHALL 在首次初始化数据库时创建且仅创建一个默认账户，名为"钱包"。该账户 SHALL 具有 is_preset=true 和 is_archived=false。

#### Scenario: 首次启动账户
- **WHEN** App 数据库首次创建
- **THEN** SHALL 存在且仅存在一条账户记录：name="钱包"、type="cash"、is_preset=true

### Requirement: 隐式默认账户绑定
所有交易 SHALL 自动绑定到默认"钱包"账户，除非用户已开启多账户模式并明确选择了其他账户。

#### Scenario: 不选择账户时的默认绑定
- **WHEN** 用户创建交易且未选择账户
- **THEN** 系统 SHALL 将默认"钱包"账户赋给 account_id

### Requirement: 多账户按需开启
多账户功能 SHALL 默认关闭。用户 MUST 在设置中明确开启。关闭时，记账流程 SHALL NOT 出现账户选择。开关状态 SHALL 通过 shared_preferences 持久化（key: `multi_account_enabled`，默认 false）。

#### Scenario: 默认模式隐藏账户选择
- **WHEN** 多账户模式关闭（默认状态）
- **THEN** 记账流程 SHALL NOT 向用户展示账户选择

#### Scenario: 开启多账户模式
- **WHEN** 用户在设置中开启多账户模式
- **THEN** 记账流程 SHALL 出现账户选择

#### Scenario: 开关状态跨重启持久化
- **WHEN** 用户开启多账户模式后重启 App
- **THEN** 多账户模式 SHALL 仍为开启状态

### Requirement: 自定义账户 CRUD
多账户模式开启后，用户 SHALL 能够创建、查看、编辑和软删除（归档）自定义账户。每个账户 SHALL 包含：name（必填）、type（cash/bank_card/credit_card/wechat/alipay/custom）、icon、color。

#### Scenario: 创建自定义账户
- **WHEN** 用户创建一个新账户 name="招商银行"、type="bank_card"
- **THEN** 系统 SHALL 持久化该账户，is_preset=false，生成新 UUID

#### Scenario: 归档账户
- **WHEN** 用户归档一个账户
- **THEN** is_archived SHALL 设为 true，该账户 SHALL 不再出现在活跃账户列表中，但其历史交易 SHALL 保持完整

### Requirement: 预设账户保护
默认"钱包"账户（is_preset=true）SHALL NOT 可被删除或归档。用户 MAY 重命名它。

#### Scenario: 尝试删除预设账户
- **WHEN** 用户尝试删除"钱包"账户
- **THEN** 系统 SHALL 拒绝该操作

### Requirement: 记账余额计算
系统 SHALL 按以下公式计算记账余额：initial_balance + SUM(收入金额) + SUM(转入金额) - SUM(支出金额) - SUM(转出金额)，仅计算非草稿状态的交易。记账余额仅反映已记录交易的累计值，并非账户真实余额。

P1 阶段默认单账户模式下 SHALL NOT 向用户展示记账余额。多账户模式开启后 MAY 在账户详情中展示，并标注"基于已记录交易"。

#### Scenario: 混合交易后的记账余额
- **WHEN** 某账户 initial_balance=0，有收入=1000、支出=300、转出=200、转入=100
- **THEN** 记账余额 SHALL 为 600

#### Scenario: 有初始余额的记账余额
- **WHEN** 某账户 initial_balance=5000，有支出=300
- **THEN** 记账余额 SHALL 为 4700

#### Scenario: 默认单账户模式不展示余额
- **WHEN** 多账户模式关闭（默认状态）
- **THEN** 系统 SHALL NOT 向用户展示账户余额，首页 SHALL 展示时间段收支汇总

### Requirement: 初始余额预留
accounts 表 SHALL 包含 initial_balance 字段（REAL，默认 0.0）。P1 阶段 SHALL NOT 在 UI 中提供初始余额设置入口，该字段为后续多账户资产管理预留。

#### Scenario: 默认账户初始余额
- **WHEN** 系统创建默认"钱包"账户
- **THEN** initial_balance SHALL 为 0.0
