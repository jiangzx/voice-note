## ADDED Requirements

### Requirement: 明细页导出按钮
交易明细页 AppBar SHALL 包含导出按钮（图标）。点击后 SHALL 以当前页面的筛选条件（日期范围、分类等）为默认值展示导出选项 Sheet。

#### Scenario: 导出当前筛选结果
- **WHEN** 用户在明细页筛选了"2026-02"的支出记录并点击导出按钮
- **THEN** 系统 SHALL 展示导出选项 Sheet，时间范围默认为 2026-02-01 至 2026-02-28，类型默认为"支出"

#### Scenario: 无筛选时导出
- **WHEN** 用户在明细页未设置任何筛选直接点击导出按钮
- **THEN** 系统 SHALL 展示导出选项 Sheet，筛选条件为空（导出全部）
