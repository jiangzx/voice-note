## Purpose

定义交易明细列表的系统行为，包括按日分组展示、条目样式、日期/类型/关键词/高级筛选、交易操作（编辑/删除）和快速记账入口。

## Requirements

### Requirement: 按日分组展示交易
系统 SHALL 将交易记录按日期分组展示。每组 SHALL 包含日期标题和当日收支小计（当日总收入、当日总支出，转账不计入）。组内交易按 created_at DESC 排序，组间按日期 DESC 排序。加载时 SHALL 展示骨架屏占位符。无数据时 SHALL 展示统一空状态组件。加载失败时 SHALL 展示统一错误组件。数据加载完成时 SHALL 以淡入动画展示。所有间距 SHALL 使用设计令牌。

#### Scenario: 展示按日分组的交易
- **WHEN** 用户进入明细列表且存在多日交易
- **THEN** 交易 SHALL 按日期分组展示，最新日期在前

#### Scenario: 每日小计
- **WHEN** 某日有支出=100、收入=300、转账=200
- **THEN** 该日小计 SHALL 展示收入=300、支出=100（转账不计入）

#### Scenario: 空列表状态
- **WHEN** 当前筛选条件下无匹配交易
- **THEN** 系统 SHALL 展示统一空状态组件

#### Scenario: 列表加载骨架屏
- **WHEN** 交易列表数据正在加载
- **THEN** 系统 SHALL 展示骨架屏占位符

#### Scenario: 加载失败重试
- **WHEN** 交易列表数据加载失败
- **THEN** 系统 SHALL 展示统一错误组件，用户触发重试后 SHALL 重新加载

#### Scenario: 数据入场动画
- **WHEN** 交易列表从加载状态变为有数据
- **THEN** 列表内容 SHALL 以淡入动画展示

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
系统 SHALL 提供搜索输入，按 description 字段进行不区分大小写的部分匹配搜索。搜索文本输入控制器 SHALL 在组件生命周期内正确管理，SHALL 与外部状态保持同步。

#### Scenario: 搜索匹配
- **WHEN** 用户输入搜索关键词"午饭"
- **THEN** 系统 SHALL 仅展示 description 包含"午饭"的交易

#### Scenario: 搜索无结果
- **WHEN** 搜索关键词无匹配交易
- **THEN** 系统 SHALL 展示统一空状态组件

#### Scenario: 搜索控制器同步
- **WHEN** 筛选条件被外部重置
- **THEN** 搜索输入框的文本 SHALL 同步清空

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

### Requirement: 列表设计令牌应用
明细列表的所有 UI 组件 SHALL 使用设计令牌定义的间距、圆角值。

#### Scenario: 间距统一
- **WHEN** 明细列表渲染
- **THEN** 所有组件间距 SHALL 引用 `AppSpacing` 常量

### Requirement: 列表性能优化
交易列表 SHALL 确保大数据量下的滚动流畅度。列表项子组件 SHALL 最大化使用 `const` 构造函数，`Dismissible` 组件 SHALL 使用稳定的 `ValueKey`。

#### Scenario: 大数据量滚动
- **WHEN** 交易列表包含 500+ 条记录
- **THEN** 滚动帧率 SHALL 保持流畅（无明显掉帧）

### Requirement: 明细页导出按钮
交易明细页 AppBar SHALL 包含导出按钮（图标）。点击后 SHALL 展示导出选项 Sheet。

> **实际行为**：当前实现以当前日历月作为导出 Sheet 的默认时间范围（initialDateFrom/initialDateTo），类型默认为未设置（initialType: null），用户可在 Sheet 内选择。

#### Scenario: 从明细页打开导出
- **WHEN** 用户在明细页点击导出按钮
- **THEN** 系统 SHALL 展示导出选项 Sheet，时间范围默认为当前日历月起止日期

#### Scenario: 无筛选时导出
- **WHEN** 用户在导出 Sheet 中不设置时间或类型即开始导出
- **THEN** 系统 SHALL 导出全部数据（由 ExportConfig 未设 dateFrom/dateTo/type 时的语义决定）
