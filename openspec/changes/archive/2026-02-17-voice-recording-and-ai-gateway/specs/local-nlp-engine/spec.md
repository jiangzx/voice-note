## ADDED Requirements

### Requirement: 本地规则引擎交易解析
系统 SHALL 在客户端本地实现基于规则的 NLP 引擎，从用户自然语言输入中提取结构化交易信息。解析 SHALL 优先于 Server LLM 调用执行。本地解析 SHALL 在无网络环境下可用。

#### Scenario: 完整信息本地解析
- **WHEN** 用户输入"昨天打车花了28块5"
- **THEN** 本地引擎 SHALL 提取 amount=28.5、date=昨天、category=交通、type=EXPENSE、description=打车

#### Scenario: 部分信息本地解析
- **WHEN** 用户输入"午饭35"
- **THEN** 本地引擎 SHALL 提取 amount=35、category=餐饮、type=EXPENSE；date 和 description 可为 null

#### Scenario: 本地解析失败回退 LLM
- **WHEN** 用户输入"上周三和朋友在太古里吃了个日料688"（复杂句式）且本地引擎无法完整解析
- **THEN** 系统 SHALL 将原始文本发送到 Server LLM 端点进行解析

### Requirement: 金额提取
本地引擎 SHALL 使用正则表达式从文本中提取金额。SHALL 支持以下格式：纯数字（35、28.5）、带单位（35块、28元、¥35、35.5块钱）、中文数字（三十五）。

#### Scenario: 阿拉伯数字金额
- **WHEN** 文本包含"花了35"
- **THEN** 系统 SHALL 提取 amount=35.0

#### Scenario: 带单位金额
- **WHEN** 文本包含"28块5"
- **THEN** 系统 SHALL 提取 amount=28.5

#### Scenario: 带货币符号金额
- **WHEN** 文本包含"¥188"
- **THEN** 系统 SHALL 提取 amount=188.0

### Requirement: 日期提取
本地引擎 SHALL 从文本中提取日期信息。SHALL 支持以下格式：相对日期（今天、昨天、前天）、星期引用（周一、上周三）、绝对日期（2月15号、2月15日）。无日期信息时 SHALL 返回 null。

#### Scenario: 相对日期转换
- **WHEN** 文本包含"昨天"且今天是 2026-02-17
- **THEN** 系统 SHALL 提取 date="2026-02-16"

#### Scenario: 星期引用转换
- **WHEN** 文本包含"上周三"且今天是 2026-02-17（周二）
- **THEN** 系统 SHALL 提取 date="2026-02-12"

#### Scenario: 无日期信息
- **WHEN** 文本为"午饭35"（无日期词汇）
- **THEN** 系统 SHALL 返回 date=null

### Requirement: 分类匹配
本地引擎 SHALL 维护一个关键词→分类映射表，将文本中的关键词匹配到预定义分类。映射表 SHALL 涵盖 PRD 中定义的所有预设分类关键词。用户自定义分类 SHALL 也纳入匹配范围。

#### Scenario: 关键词匹配分类
- **WHEN** 文本包含"打车"
- **THEN** 系统 SHALL 匹配到分类"交通"

#### Scenario: 自定义分类匹配
- **WHEN** 用户有自定义分类"学习资料"且文本包含"学习资料"
- **THEN** 系统 SHALL 匹配到自定义分类"学习资料"

#### Scenario: 收入类型识别
- **WHEN** 文本包含"发工资"或"收到红包"
- **THEN** 系统 SHALL 提取 type=INCOME 并匹配对应收入分类

### Requirement: 交易类型推断
本地引擎 SHALL 根据文本中的动词和关键词推断交易类型。默认类型 SHALL 为 EXPENSE。包含"花了/买了/付了/消费"等动词 SHALL 推断为 EXPENSE；包含"工资/收入/收到/进账"SHALL 推断为 INCOME；包含"转账/转给/转到"SHALL 推断为 TRANSFER。

#### Scenario: 默认支出类型
- **WHEN** 文本为"午饭35"（无明确类型动词）
- **THEN** 系统 SHALL 推断 type=EXPENSE

#### Scenario: 收入类型推断
- **WHEN** 文本为"收到红包200"
- **THEN** 系统 SHALL 推断 type=INCOME

#### Scenario: 转账类型推断
- **WHEN** 文本为"转账给小明500"
- **THEN** 系统 SHALL 推断 type=TRANSFER
