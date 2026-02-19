## ADDED Requirements

### Requirement: Tab 切换转场
系统 SHALL 在底部导航 Tab 切换时应用 FadeThroughTransition 动画。过渡时长 SHALL 使用设计令牌中定义的标准时长。

#### Scenario: 从首页切换到明细
- **WHEN** 用户从首页 Tab 切换到明细 Tab
- **THEN** 系统 SHALL 以 FadeThrough 效果过渡，旧页面淡出同时新页面淡入

#### Scenario: 快速连续切换
- **WHEN** 用户快速连续点击多个 Tab
- **THEN** 系统 SHALL 中断进行中的动画，直接过渡到最终目标 Tab

### Requirement: Push 路由转场
系统 SHALL 在 Push 模式的路由导航（记账、账户管理、分类管理）应用 SharedAxisTransition (Y 轴) 动画。

#### Scenario: 打开记账页面
- **WHEN** 用户导航至记账页面
- **THEN** 系统 SHALL 以 Y 轴 SharedAxis 效果推入新页面

#### Scenario: 返回上一级
- **WHEN** 用户从记账页面返回
- **THEN** 系统 SHALL 以反向 Y 轴 SharedAxis 效果退出页面

### Requirement: FAB 转场动画
系统 SHALL 在 FAB 触发记账时应用容器变换动画（OpenContainer），FAB SHALL 作为起始容器展开为记账全屏页面。

#### Scenario: FAB 展开为记账页
- **WHEN** 用户触发 FAB 记账入口
- **THEN** FAB SHALL 以容器变换动画平滑展开为记账页面

#### Scenario: 从记账返回收缩
- **WHEN** 用户从 FAB 触发的记账页面返回
- **THEN** 记账页面 SHALL 以反向容器变换动画收缩回 FAB

### Requirement: 列表项入场动画
系统 SHALL 在交易列表和首页最近交易列表数据加载完成时，以淡入动画展示列表内容。

#### Scenario: 列表数据加载完成
- **WHEN** 交易列表从加载状态变为有数据状态
- **THEN** 列表内容 SHALL 以淡入效果出现

#### Scenario: 列表刷新
- **WHEN** 列表筛选条件变更导致数据刷新
- **THEN** 新数据 SHALL 以淡入效果替换旧数据

### Requirement: 数值变化动画
系统 SHALL 在金额显示数值变化时应用平滑的文本样式过渡动画。

#### Scenario: 金额输入变化
- **WHEN** 用户在记账页面输入金额导致数值变化
- **THEN** 金额显示 SHALL 以平滑的字体大小/颜色过渡展示变化
