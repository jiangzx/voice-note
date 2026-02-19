## MODIFIED Requirements

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

## ADDED Requirements

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
