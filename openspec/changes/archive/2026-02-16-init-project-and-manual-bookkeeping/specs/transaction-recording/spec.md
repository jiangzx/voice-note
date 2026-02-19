## ADDED Requirements

### Requirement: 交易类型
系统 SHALL 支持三种交易类型：expense（支出）、income（收入）、transfer（转账）。

#### Scenario: 创建支出
- **WHEN** 用户记录一笔 type="expense" 的交易
- **THEN** 系统 SHALL 持久化该记录，包含有效的 category_id 和 account_id

#### Scenario: 创建收入
- **WHEN** 用户记录一笔 type="income" 的交易
- **THEN** 系统 SHALL 持久化该记录，包含有效的 category_id 和 account_id

#### Scenario: 创建转账
- **WHEN** 用户记录一笔 type="transfer" 的交易
- **THEN** 系统 SHALL 持久化该记录，包含 account_id、transfer_direction（in/out）和可选的 counterparty。category_id MAY 为 null。

### Requirement: 最少必填字段
非草稿交易仅需两个必填字段：amount（正数）和 category_id（转账类型除外，转账可不填分类）。日期 SHALL 自动填充为今天。描述 SHALL 为可选。

#### Scenario: 最简有效支出
- **WHEN** 用户仅提供 amount=35 和 category="餐饮"
- **THEN** 系统 SHALL 创建一条有效的支出记录，date=今天、description=null、account=默认钱包

#### Scenario: 拒绝无金额的交易
- **WHEN** 用户尝试保存一条没有 amount 的交易
- **THEN** 系统 SHALL 拒绝并提示缺少字段

#### Scenario: 拒绝无分类的支出
- **WHEN** 用户尝试保存一条没有 category_id 的支出交易
- **THEN** 系统 SHALL 拒绝并提示缺少字段

### Requirement: 日期自动填充
日期 SHALL 默认为今天（当前日期）。系统 SHALL 提供"今天/昨天/前天"快捷选项。用户 MAY 通过日期选择器选择其他日期。

#### Scenario: 默认日期为今天
- **WHEN** 用户打开记账流程
- **THEN** 日期字段 SHALL 预填为今天

#### Scenario: 快捷选择昨天
- **WHEN** 用户选择"昨天"快捷选项
- **THEN** 日期 SHALL 设为昨天

### Requirement: 描述可选
描述（事件描述）SHALL 为可选字段。未填写时，系统 MAY 在列表展示中使用分类名称作为显示描述。

#### Scenario: 不填描述的交易
- **WHEN** 用户保存一笔不填描述的交易
- **THEN** 系统 SHALL 将 description 存为 null，在列表中展示分类名称

### Requirement: 转账单账户视角
转账交易 SHALL 绑定且仅绑定一个账户。转账方向通过 transfer_direction 字段（in 或 out）表达。counterparty 字段（可选文本）MAY 记录对方信息（其他账户名或人名）。

#### Scenario: 转出
- **WHEN** 用户记录"支付宝转出500"
- **THEN** 系统 SHALL 创建：type=transfer、account_id=支付宝、transfer_direction=out、amount=500

#### Scenario: 带对方信息的转入
- **WHEN** 用户记录"小明转给我支付宝300"
- **THEN** 系统 SHALL 创建：type=transfer、account_id=支付宝、transfer_direction=in、counterparty="小明"、amount=300

### Requirement: 可选转账配对
两条转账记录 MAY 通过 linked_transaction_id 互相关联（表示同一笔转账的两侧）。关联为可选，SHALL NOT 强制。P1 阶段仅预留字段，暂不实现自动匹配。

#### Scenario: 独立的转账记录
- **WHEN** 用户分别记录"支付宝转出500"和"银行卡转入500"
- **THEN** 两条记录 SHALL 各自独立有效，linked_transaction_id=null

### Requirement: 交易 CRUD
用户 SHALL 能够创建、查看、编辑和删除交易。

#### Scenario: 编辑交易金额
- **WHEN** 用户将某笔交易的 amount 从 35 修改为 45
- **THEN** 系统 SHALL 持久化更新后的金额并更新 updated_at 时间戳

#### Scenario: 删除交易
- **WHEN** 用户删除一笔交易
- **THEN** 该记录 SHALL 从数据库中永久移除

#### Scenario: 删除有配对的转账交易
- **WHEN** 用户删除一笔转账交易 A，且存在另一笔交易 B 通过 linked_transaction_id 关联到 A
- **THEN** A SHALL 被永久移除，B 的 linked_transaction_id SHALL 被置为 null（解除配对关系）

### Requirement: 金额正数约束
交易金额 SHALL 始终为大于零的正数。

#### Scenario: 拒绝零金额
- **WHEN** 用户尝试保存 amount=0 的交易
- **THEN** 系统 SHALL 拒绝该操作

#### Scenario: 拒绝负金额
- **WHEN** 用户尝试保存 amount=-50 的交易
- **THEN** 系统 SHALL 拒绝该操作
