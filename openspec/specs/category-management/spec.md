## Purpose

定义分类管理能力，包括预设分类初始化（支出/收入）、自定义分类的创建/编辑/删除/隐藏、拖拽排序及预设分类保护策略。

## Requirements

### Requirement: 预设分类初始化
系统 SHALL 在首次初始化数据库时播种预设分类：12 个支出分类（10 个可见 + 2 个初始隐藏）和 5 个收入分类。所有预设分类 SHALL 具有 is_preset=true。

#### Scenario: 首次启动分类数量
- **WHEN** App 数据库首次创建
- **THEN** SHALL 存在 17 条预设分类记录（12 支出 + 5 收入）

#### Scenario: 初始隐藏分类
- **WHEN** 数据库初始化完成
- **THEN** "宠物"和"旅行"分类 SHALL 具有 is_hidden=true，其余 SHALL 为 is_hidden=false

### Requirement: 预设支出分类
预设支出分类 SHALL 包含：餐饮、交通、购物、账单、娱乐、医疗、教育、住房、人情往来、其他（可见）；宠物、旅行（初始隐藏）。每个 SHALL 具有 type="expense"。

#### Scenario: 查询可见支出分类
- **WHEN** 查询可见的支出分类列表
- **THEN** 系统 SHALL 返回恰好 10 个分类，排除隐藏项

### Requirement: 预设收入分类
预设收入分类 SHALL 包含：工资、奖金、兼职、红包、其他。每个 SHALL 具有 type="income"。

#### Scenario: 查询收入分类
- **WHEN** 查询收入分类列表
- **THEN** 系统 SHALL 返回恰好 5 个分类

### Requirement: 自定义分类 CRUD
用户 SHALL 能够创建、编辑和删除自定义分类。每个分类 SHALL 包含：name（必填）、type（expense/income，必填）、icon、color。

#### Scenario: 创建自定义分类
- **WHEN** 用户创建分类 name="学习资料"、type="expense"
- **THEN** 系统 SHALL 持久化该分类，is_preset=false、is_hidden=false

#### Scenario: 删除无引用的自定义分类
- **WHEN** 用户删除一个自定义分类（is_preset=false）且无任何交易引用该分类
- **THEN** 该分类 SHALL 被从数据库中移除（硬删除）

#### Scenario: 删除有引用的自定义分类
- **WHEN** 用户删除一个自定义分类（is_preset=false）且有交易引用该分类
- **THEN** 系统 SHALL 将该分类的 is_hidden 设为 true（软删除），保留数据完整性。该分类 SHALL NOT 出现在记账选择列表中，但历史交易 SHALL 正常显示该分类名称

### Requirement: 预设分类保护
预设分类（is_preset=true）SHALL NOT 可被删除。可以隐藏（is_hidden=true）或重新排序。

#### Scenario: 隐藏预设分类
- **WHEN** 用户隐藏一个预设分类
- **THEN** is_hidden SHALL 设为 true，该分类 SHALL NOT 出现在记账选择列表中，但 SHALL 仍出现在历史交易中

#### Scenario: 尝试删除预设分类
- **WHEN** 用户尝试删除预设分类
- **THEN** 系统 SHALL 拒绝该操作

### Requirement: 分类排序
用户 SHALL 能够对分类进行重新排序。系统 SHALL 持久化 sort_order 值。分类 SHALL 按 sort_order 升序展示。

#### Scenario: 重新排序分类
- **WHEN** 用户将"交通"移到"餐饮"前面
- **THEN** sort_order 值 SHALL 更新，使"交通"排在最前

### Requirement: 智能分类排序
分类选择列表 SHALL 采用分层排序策略，三种机制互不冲突：

1. **最近使用区域**（列表顶部独立区域）：展示最近 3 个使用过的分类，作为快捷入口
2. **时段推荐**（视觉高亮）：根据当前时段在完整列表中对匹配分类添加高亮标记（如推荐 badge），不改变排列位置
3. **用户手动排序**（基准顺序）：完整分类列表按用户定义的 sort_order 升序排列

追踪机制：通过查询 transactions 表按 created_at DESC 取最近 N 条不重复的 category_id 动态推导，不新增额外字段或表。

#### Scenario: 最近使用分类快捷区域
- **WHEN** 用户最近三次分别使用了"交通"、"餐饮"、"购物"分类
- **THEN** 分类选择列表顶部 SHALL 展示"最近使用"区域，包含这三个分类

#### Scenario: 无交易历史时无最近使用区域
- **WHEN** 用户首次使用 App 且无任何交易记录
- **THEN** 分类选择列表 SHALL NOT 展示"最近使用"区域，仅展示完整分类列表

#### Scenario: 单分类时段推荐
- **WHEN** 用户在 11:00-13:00 之间打开记账流程
- **THEN** 完整分类列表中"餐饮"分类 SHALL 被高亮标记（如添加推荐 badge），但排列位置不变

#### Scenario: 多分类时段推荐
- **WHEN** 用户在 17:00-19:00 之间打开记账流程（同时匹配晚餐和晚通勤）
- **THEN** "餐饮"和"交通"分类 SHALL 同时被高亮标记

#### Scenario: 手动排序作为基准
- **WHEN** 用户将"交通"手动移到"餐饮"前面
- **THEN** 完整分类列表 SHALL 按更新后的 sort_order 排列，"交通"在"餐饮"前面
