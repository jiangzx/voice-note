## ADDED Requirements

### Requirement: 按日分组展示交易
系统 SHALL 将交易记录按日期分组展示。每组 SHALL 包含日期标题和当日收支小计（当日总收入、当日总支出，转账不计入）。组内交易按 created_at DESC 排序，组间按日期 DESC 排序。

#### Scenario: 展示按日分组的交易
- **WHEN** 用户进入明细列表且存在多日交易
- **THEN** 交易 SHALL 按日期分组展示，最新日期在前

#### Scenario: 每日小计
- **WHEN** 某日有支出=100、收入=300、转账=200
- **THEN** 该日小计 SHALL 展示收入=300、支出=100（转账不计入）

#### Scenario: 空列表状态
- **WHEN** 当前筛选条件下无匹配交易
- **THEN** 系统 SHALL 展示空状态提示

### Requirement: 交易条目展示
每条交易记录 SHALL 展示：分类图标、分类名称或描述（description 非空优先展示 description，否则展示分类名称）、金额（支出为红色系负数、收入为绿色系正数、转账为蓝色系并标注方向）、日期。

#### Scenario: 支出条目展示
- **WHEN** 列表中包含一笔支出：category="餐饮"、amount=35、description=null
- **THEN** SHALL 展示分类图标、"餐饮"作为标题、"-¥35.00" 红色系金额

#### Scenario: 带描述的条目
- **WHEN** 列表中包含一笔交易：category="餐饮"、description="午餐"
- **THEN** SHALL 展示"午餐"作为标题（优先于分类名称）

#### Scenario: 转账条目展示
- **WHEN** 列表中包含一笔转账：transfer_direction=outbound、counterparty="小明"、amount=500
- **THEN** SHALL 展示转账图标、标注转出方向和对方信息、"¥500.00" 蓝色系金额

### Requirement: 日期范围快捷筛选
系统 SHALL 提供日期范围快捷筛选选项：今天、本周、本月（默认）、本年。用户 MAY 选择自定义日期范围。

#### Scenario: 默认展示本月
- **WHEN** 用户首次进入明细列表
- **THEN** SHALL 默认展示本月的交易记录

#### Scenario: 切换到本周
- **WHEN** 用户选择"本周"筛选
- **THEN** 系统 SHALL 仅展示本周日期范围内的交易

#### Scenario: 自定义日期范围
- **WHEN** 用户选择自定义日期范围 2026-01-01 至 2026-01-31
- **THEN** 系统 SHALL 仅展示该范围内的交易

### Requirement: 类型筛选
系统 SHALL 支持按交易类型筛选（全部、支出、收入、转账），默认展示全部类型。

#### Scenario: 筛选仅支出
- **WHEN** 用户选择"支出"类型筛选
- **THEN** 系统 SHALL 仅展示 type=expense 的交易

#### Scenario: 默认全部类型
- **WHEN** 用户未选择类型筛选
- **THEN** 系统 SHALL 展示所有类型的交易

### Requirement: 关键词搜索
系统 SHALL 提供搜索输入，按 description 字段进行不区分大小写的部分匹配搜索。

#### Scenario: 搜索匹配
- **WHEN** 用户输入搜索关键词"午饭"
- **THEN** 系统 SHALL 仅展示 description 包含"午饭"的交易

#### Scenario: 搜索无结果
- **WHEN** 搜索关键词无匹配交易
- **THEN** 系统 SHALL 展示空状态提示

### Requirement: 高级筛选
系统 SHALL 支持通过展开面板设置高级筛选条件：分类（多选）、金额范围（最小/最大值）、账户（多账户模式下）。多个筛选条件 SHALL 以 AND 逻辑组合。

#### Scenario: 按分类筛选
- **WHEN** 用户选择分类筛选"餐饮"和"交通"
- **THEN** 系统 SHALL 仅展示 category_id 匹配"餐饮"或"交通"的交易

#### Scenario: 按金额范围筛选
- **WHEN** 用户设置最小金额=100、最大金额=500
- **THEN** 系统 SHALL 仅展示金额在 100-500 范围内的交易

#### Scenario: 组合筛选
- **WHEN** 用户同时选择"本月" + "支出" + "餐饮"
- **THEN** 系统 SHALL 仅展示同时满足三个条件的交易

### Requirement: 交易操作
用户 SHALL 能够从列表中对交易执行操作：编辑（导航至记账流程并回填）和删除（确认后执行）。

#### Scenario: 编辑交易
- **WHEN** 用户对某条交易触发编辑操作
- **THEN** 系统 SHALL 导航至记账流程并回填该交易数据

#### Scenario: 删除交易
- **WHEN** 用户对某条交易触发删除操作并确认
- **THEN** 系统 SHALL 从数据库中移除该记录并刷新列表

#### Scenario: 删除确认
- **WHEN** 用户触发删除操作
- **THEN** 系统 SHALL 先请求确认，未确认则不执行删除

### Requirement: 快速记账入口
系统 SHALL 在明细列表提供快速记账入口（与首页一致），触发后导航至记账流程。

#### Scenario: 从列表触发记账
- **WHEN** 用户通过明细列表的快速入口触发记账
- **THEN** 系统 SHALL 导航至记账流程，表单状态为初始状态
