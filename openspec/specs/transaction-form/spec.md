## Purpose

定义记账表单的系统行为，包括金额输入、类型切换、分类选择、日期选择、描述输入、转账字段、账户选择、保存校验和编辑回填。

## Requirements

### Requirement: 金额数字键盘输入
系统 SHALL 提供自定义数字键盘（0-9、小数点、退格）用于金额输入。金额 SHALL 以字符串形式管理，仅在保存时转为数值。限制：最多 2 位小数，最大值 99999999.99。键盘按键列表 SHALL 为静态常量，SHALL NOT 在每次 build 时重新创建。

#### Scenario: 输入整数金额
- **WHEN** 用户依次输入 3、5
- **THEN** 金额显示 SHALL 为 "35"

#### Scenario: 输入小数金额
- **WHEN** 用户依次输入 1、2、.、5
- **THEN** 金额显示 SHALL 为 "12.5"

#### Scenario: 小数位数限制
- **WHEN** 金额已为 "12.55" 且用户尝试输入更多数字
- **THEN** 系统 SHALL 忽略该输入，金额保持 "12.55"

#### Scenario: 退格操作
- **WHEN** 金额为 "35" 且用户触发退格
- **THEN** 金额 SHALL 变为 "3"

#### Scenario: 前导零处理
- **WHEN** 金额为 "0" 且用户输入 5
- **THEN** 金额 SHALL 变为 "5"（不显示为 "05"）

#### Scenario: 空金额展示
- **WHEN** 表单初始化或金额被完全退格
- **THEN** 金额显示 SHALL 为 "0"

### Requirement: 交易类型切换
系统 SHALL 支持在支出、收入、转账三种类型之间切换。切换类型 SHALL 更新 `TransactionForm` 状态，并根据类型动态调整表单内容。

#### Scenario: 默认类型为支出
- **WHEN** 记账流程初始化
- **THEN** 交易类型 SHALL 默认为"支出"

#### Scenario: 切换到收入
- **WHEN** 用户将类型切换为"收入"
- **THEN** 分类选择区域 SHALL 展示收入分类列表

#### Scenario: 切换到转账
- **WHEN** 用户将类型切换为"转账"
- **THEN** 分类选择区域 SHALL 隐藏，转账专属字段（方向、对方信息）SHALL 展示

### Requirement: 分类选择
系统 SHALL 以网格方式展示分类列表，每项包含图标和名称。分类列表 SHALL 按 `visibleCategoriesProvider` 获取，根据当前选中的交易类型（支出/收入）过滤。

#### Scenario: 展示支出分类网格
- **WHEN** 交易类型为"支出"
- **THEN** 系统 SHALL 展示可见支出分类的网格列表

#### Scenario: 选中分类
- **WHEN** 用户选择"餐饮"分类
- **THEN** `TransactionForm` 的 categoryId SHALL 更新为"餐饮"的 ID，选中项 SHALL 有视觉区分

#### Scenario: 转账时隐藏分类
- **WHEN** 交易类型为"转账"
- **THEN** 分类选择区域 SHALL NOT 展示

### Requirement: 最近使用分类快捷区
当存在交易历史时，系统 SHALL 在分类网格上方展示最近使用的分类（最多 3 个）作为快捷选择入口。数据来自 `recentCategoriesProvider`。

#### Scenario: 展示最近使用分类
- **WHEN** 用户有交易历史且最近使用了"餐饮"、"交通"、"购物"
- **THEN** 系统 SHALL 在分类列表顶部展示这三个分类的快捷入口

#### Scenario: 无历史时不展示
- **WHEN** 用户无任何交易记录
- **THEN** 最近使用分类区域 SHALL NOT 展示

### Requirement: 时段推荐分类高亮
系统 SHALL 根据当前时段对匹配的分类添加视觉高亮标记。推荐数据来自 `recommendedCategoryNamesProvider`。高亮仅为视觉提示，不改变分类的排列顺序。

#### Scenario: 午餐时段推荐
- **WHEN** 当前时间在 11:00-13:00 之间
- **THEN** "餐饮"分类 SHALL 具有视觉高亮标记

#### Scenario: 无匹配时段
- **WHEN** 当前时间不匹配任何预定义时段
- **THEN** 所有分类 SHALL 无高亮标记

### Requirement: 日期选择
系统 SHALL 默认将日期设为今天，并提供快捷选项（今天、昨天、前天）和日期选择器。

#### Scenario: 默认日期为今天
- **WHEN** 记账流程初始化
- **THEN** 日期 SHALL 为当天日期

#### Scenario: 快捷选择昨天
- **WHEN** 用户选择"昨天"快捷选项
- **THEN** 日期 SHALL 更新为昨天

#### Scenario: 自定义日期选择
- **WHEN** 用户通过日期选择器选择 2026-01-15
- **THEN** 日期 SHALL 更新为 2026-01-15

### Requirement: 描述输入
系统 SHALL 提供可选的描述文本输入字段。未填写时 SHALL 保持为 null。

#### Scenario: 输入描述
- **WHEN** 用户在描述字段输入"午餐"
- **THEN** `TransactionForm` 的 description SHALL 更新为"午餐"

#### Scenario: 不填描述
- **WHEN** 用户不输入描述直接保存
- **THEN** description SHALL 为 null

### Requirement: 转账专属字段
当交易类型为转账时，系统 SHALL 展示转账方向选择（转入/转出）和可选的对方信息输入。对方信息的文本输入控制器 SHALL 在组件生命周期内正确管理（创建于 initState，释放于 dispose），SHALL NOT 在 build 方法中重复创建。

#### Scenario: 选择转出方向
- **WHEN** 类型为转账且用户选择"转出"
- **THEN** `TransactionForm` 的 transferDirection SHALL 为 outbound

#### Scenario: 输入对方信息
- **WHEN** 类型为转账且用户输入对方信息"小明"
- **THEN** `TransactionForm` 的 counterparty SHALL 更新为"小明"

#### Scenario: 对方信息可选
- **WHEN** 类型为转账且用户不输入对方信息
- **THEN** counterparty SHALL 为 null

#### Scenario: 控制器生命周期
- **WHEN** 转账字段组件从 Widget 树中移除
- **THEN** 文本输入控制器 SHALL 被正确释放，不产生内存泄漏

### Requirement: 账户选择（多账户模式）
当多账户模式开启时，记账流程 SHALL 展示账户选择。默认选中默认账户。当多账户模式关闭时，SHALL NOT 展示账户选择，自动绑定默认账户。

#### Scenario: 多账户模式下选择账户
- **WHEN** 多账户模式已开启
- **THEN** 系统 SHALL 展示活跃账户列表供用户选择

#### Scenario: 单账户模式隐藏账户选择
- **WHEN** 多账户模式关闭
- **THEN** 系统 SHALL NOT 展示账户选择，accountId SHALL 自动绑定默认账户

### Requirement: 保存交易
系统 SHALL 在用户确认保存时校验必填字段（金额 > 0、非转账需有分类），校验通过后调用 `TransactionRepository.create` 持久化记录，然后导航回上一级。

#### Scenario: 成功保存支出
- **WHEN** 用户填写 amount=35、category="餐饮" 并确认保存
- **THEN** 系统 SHALL 创建交易记录并导航回上一级

#### Scenario: 金额为零时拒绝保存
- **WHEN** 用户未输入金额（amount=0）并尝试保存
- **THEN** 系统 SHALL 提示金额不能为零，不执行保存

#### Scenario: 缺少分类时拒绝保存
- **WHEN** 交易类型为支出且未选择分类
- **THEN** 系统 SHALL 提示需要选择分类，不执行保存

### Requirement: 编辑交易回填
当从编辑模式进入记账流程时，系统 SHALL 将已有交易的所有字段回填到表单状态。

#### Scenario: 回填已有交易
- **WHEN** 用户从交易列表选择编辑一笔交易（amount=50、category="交通"、date=2026-02-10）
- **THEN** 表单 SHALL 预填为：amount=50、category="交通"、date=2026-02-10

#### Scenario: 编辑后保存
- **WHEN** 用户修改金额为 60 并保存
- **THEN** 系统 SHALL 调用 update 更新交易记录

### Requirement: 表单设计令牌应用
记账流程的所有 UI 组件 SHALL 使用设计令牌定义的间距、圆角值，替代硬编码数值。

#### Scenario: 间距统一
- **WHEN** 记账流程渲染
- **THEN** 所有组件间距 SHALL 引用 `AppSpacing` 常量

### Requirement: 金额数值变化动画
金额显示区域 SHALL 在数值变化时应用平滑的样式过渡动画。

#### Scenario: 输入数字后动画过渡
- **WHEN** 用户输入数字导致金额变化
- **THEN** 金额文本 SHALL 以平滑动画过渡到新样式
