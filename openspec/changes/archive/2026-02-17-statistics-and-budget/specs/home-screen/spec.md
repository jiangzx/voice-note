## ADDED Requirements

### Requirement: 首页预算进度摘要
系统 SHALL 在首页展示当月预算使用率最高的分类摘要。若无分类设置预算，该区域 SHALL NOT 展示。若有多个超支分类，SHALL 展示超支最严重的一个。摘要 SHALL 包含分类名称、已消费金额 / 预算金额、进度百分比。

#### Scenario: 展示最高使用率分类
- **WHEN** 用户有 3 个分类设置了预算，餐饮 90%、交通 50%、购物 70%
- **THEN** 首页 SHALL 展示餐饮的预算摘要（使用率最高）

#### Scenario: 超支分类优先展示
- **WHEN** 餐饮预算已超支（120%），交通正常（50%）
- **THEN** 首页 SHALL 展示餐饮的超支警告

#### Scenario: 无预算设置
- **WHEN** 用户未设置任何预算
- **THEN** 首页 SHALL NOT 展示预算摘要区域

## MODIFIED Requirements

### Requirement: 快速记账入口
系统 SHALL 在首页提供语音记账入口（居中悬浮 FAB），触发后 SHALL 导航至语音记账页（LISTENING 状态）。手动记账入口 SHALL 移至首页 AppBar 右上角（图标按钮），触发后 SHALL 导航至记账表单。语音记账 FAB SHALL 在所有底部导航 Tab 页面可见。

#### Scenario: 触发语音记账
- **WHEN** 用户点击居中语音 FAB
- **THEN** 系统 SHALL 导航至语音记账页，状态 SHALL 为 LISTENING

#### Scenario: 触发手动记账
- **WHEN** 用户点击首页右上角的记账图标按钮
- **THEN** 系统 SHALL 导航至记账流程，表单状态 SHALL 为初始状态

#### Scenario: 语音 FAB 全局可见
- **WHEN** 用户在任意底部 Tab 页面
- **THEN** 语音记账 FAB SHALL 居中悬浮可见

### Requirement: 底部导航
系统 SHALL 提供底部导航在首页、统计、明细列表、设置四个一级功能之间切换。导航状态 SHALL 在切换时保持（不重新加载）。

#### Scenario: 导航切换
- **WHEN** 用户从首页切换至统计页
- **THEN** 系统 SHALL 展示统计页内容，再切回首页时 SHALL 保持之前的滚动位置

#### Scenario: 默认展示首页
- **WHEN** App 冷启动
- **THEN** 系统 SHALL 默认展示首页

#### Scenario: 导航至统计页
- **WHEN** 用户点击底部"统计"Tab
- **THEN** 系统 SHALL 展示统计页
