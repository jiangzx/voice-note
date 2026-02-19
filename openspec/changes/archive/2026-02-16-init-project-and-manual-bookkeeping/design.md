## Context

随口记 App 从零启动，当前没有任何代码。本阶段（P0+P1）需要搭建 Flutter 项目基础架构并实现完整的手动记账功能，为后续语音输入（P2）、统计报表（P3）、数据导出（P4）、云同步（P5）等模块提供稳固的数据层和领域层基础。

核心约束：
- 跨平台：iOS + Android 同时覆盖
- 本地优先：首次使用无需登录，离线可用，数据存本地
- 可扩展：数据模型须为后续云同步、语音记账、统计报表预留扩展空间

## Goals / Non-Goals

**Goals:**

- 建立清晰的分层架构（数据层 / 领域层 / 表现层），各层职责明确、可独立测试
- 设计支持本地优先 + 未来云同步的数据模型
- 实现完整的手动记账核心功能（账户、分类、交易记录、查询）
- 确保数据完整性（必填字段校验、级联删除保护）

**Non-Goals:**

- 语音输入 / ASR / NLP（P2 范围）
- 统计报表与图表（P3 范围）
- 数据导出 CSV / PDF / JSON（P4 范围）
- 用户注册登录 / 云同步 / 多设备（P5 范围）
- Widget / Siri 集成 / 深色模式（P6 范围）
- UI 视觉设计细节（本文档关注架构与数据层，不涉及具体 UI 实现）

## Decisions

### D1: 项目架构——分层架构 + Feature-First 目录组织

**选择**：三层架构（Data → Domain → Presentation）+ 按功能模块组织目录

**理由**：
- 三层架构使数据层（drift ORM）、业务逻辑（use case）、UI 层（widget + state）解耦，便于独立测试和替换
- Feature-First 目录结构比 Layer-First 在中大型项目中更易导航和维护
- 公共基础设施（数据库初始化、通用工具）放在 `lib/core/`

**备选方案**：
- Layer-First 目录组织——项目规模增大后跨模块查找困难，放弃
- 完全扁平结构——不适合预期功能量级，放弃

**目录结构**：

```
lib/
  core/                         # shared infrastructure
    database/                   # drift database, migrations
    di/                         # dependency injection setup
    constants/                  # app-wide constants
    utils/                      # common utilities
  features/
    account/                    # account management
      data/                     # repository implementations, DAOs
      domain/                   # entities, repository interfaces, use cases
      presentation/             # widgets, state management
    category/                   # category management
      data/
      domain/
      presentation/
    transaction/                # transaction recording and query
      data/
      domain/
      presentation/
    home/                       # home page (daily summary + recent list)
      presentation/
  app.dart                      # app entry, routing, theme
```

### D2: 状态管理——Riverpod

**选择**：Riverpod（flutter_riverpod + riverpod_annotation）

**理由**：
- 编译时安全，Provider 类型错误在编译期暴露
- 支持 `autoDispose`，自动管理生命周期，避免内存泄漏
- 天然支持异步数据（`AsyncValue`），与 drift 的 Stream / Future 配合良好
- 不依赖 BuildContext，业务逻辑可在非 Widget 环境中使用（为后续语音模块做准备）

**备选方案**：
- Bloc——模板代码较多（Event + State + Bloc 三件套），对于记账这种 CRUD 密集型场景略显繁琐，放弃

### D3: 本地存储——drift（SQLite ORM）

**选择**：drift（原 moor）

**理由**：
- 类型安全的 Dart DSL 定义表结构，编译时生成代码
- 内置 migration 支持（schemaVersion + MigrationStrategy），数据库升级有保障
- 支持响应式查询（.watch()），数据变更自动推送 UI 更新
- 支持原生 SQL，复杂查询不受限
- 社区活跃，Flutter 生态中 SQLite ORM 的首选

**备选方案**：
- sqflite——手写 SQL + 手动序列化，缺乏类型安全和 migration 管理，放弃
- Hive——KV 存储，不适合关系型数据（交易关联账户、分类），放弃

### D4: 数据模型设计

**核心实体关系**：

```
Account 1---N Transaction
Category 1---N Transaction (optional for transfer)
Transaction ---(optional)--- Transaction (linked pair via linked_transaction_id)
```

**accounts 表**：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | TEXT (UUID) | 主键 |
| name | TEXT | 账户名称 |
| type | TEXT | 账户类型枚举（cash / bank_card / credit_card / wechat / alipay / custom） |
| icon | TEXT | 图标标识（格式：`material:<name>` 或 `emoji:<char>`，详见 D9） |
| color | TEXT | 颜色值（8 位 ARGB hex 不含 # 前缀，如 FF4CAF50，详见 D9） |
| is_preset | BOOLEAN | 是否预设账户（预设不可删除） |
| sort_order | INTEGER | 排序权重 |
| initial_balance | REAL | 初始余额（默认 0.0），用户可选设置，P1 阶段不在 UI 暴露 |
| is_archived | BOOLEAN | 是否归档（软删除） |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |
| sync_status | TEXT | 同步状态（local / pending / synced），P1 阶段恒为 local |
| remote_id | TEXT | 远程 ID，P1 阶段为 null |

**categories 表**：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | TEXT (UUID) | 主键 |
| name | TEXT | 分类名称 |
| type | TEXT | 收支类型（expense / income） |
| icon | TEXT | 图标标识（格式：`material:<name>` 或 `emoji:<char>`，详见 D9） |
| color | TEXT | 颜色值（8 位 ARGB hex 不含 # 前缀，如 FF4CAF50，详见 D9） |
| is_preset | BOOLEAN | 是否预定义分类 |
| is_hidden | BOOLEAN | 是否隐藏（预设分类不可删除但可隐藏） |
| sort_order | INTEGER | 排序权重 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |
| sync_status | TEXT | 同步状态 |
| remote_id | TEXT | 远程 ID |

**transactions 表**：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | TEXT (UUID) | 主键 |
| type | TEXT | 交易类型（expense / income / transfer） |
| amount | REAL | 金额（正数） |
| currency | TEXT | 币种代码（默认 CNY） |
| date | DATE | 交易日期（仅日期，无时间部分）。存储为 YYYY-MM-DD 00:00:00 UTC，业务层基于设备本地日期生成 |
| description | TEXT | 描述（可选）——事件描述 + 备注合一，如"午饭，和同事AA的"。未填写时展示层 Fallback 到分类名 |
| category_id | TEXT (FK) | 关联分类（转账时可为 null） |
| account_id | TEXT (FK) | 关联账户——每笔交易只绑定一个账户 |
| transfer_direction | TEXT | 转账方向（in / out），仅 type=transfer 时有值，其余为 null |
| counterparty | TEXT | 对方（可选）——转账对方的账户名或人名，如"银行卡"、"小明" |
| linked_transaction_id | TEXT | 配对交易 ID（可选，两笔转账记录互相关联时使用） |
| is_draft | BOOLEAN | 是否草稿 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |
| sync_status | TEXT | 同步状态 |
| remote_id | TEXT | 远程 ID |

### D5: 转账实现——单账户视角 + 可选配对

**选择**：每笔交易（含转账）只关联**一个账户**。转账通过 `transfer_direction`（in/out）表达资金方向，通过 `counterparty` 记录对方信息（可选）。用户可独立记录转账的单侧，也可记录两侧并通过 `linked_transaction_id` 关联。

**设计原则**：用户从自己最关心的那个账户视角记录，不强制指定双端。

**典型场景**：

```
"支付宝转出500"
  type=transfer, account=支付宝, direction=out, amount=500

"银行卡转入500"
  type=transfer, account=银行卡, direction=in, amount=500

"小明转给我支付宝300"
  type=transfer, account=支付宝, direction=in, counterparty=小明, amount=300

"我转给小明微信200"
  type=transfer, account=微信, direction=out, counterparty=小明, amount=200
```

**记账余额计算**（仅多账户模式下使用，详见 D12）：

```
记账余额 = initial_balance
         + SUM(income.amount)
         + SUM(transfer[direction=in].amount)
         - SUM(expense.amount)
         - SUM(transfer[direction=out].amount)
```

**可选配对**：若用户分别记录了"支付宝转出500"和"银行卡转入500"，系统可通过金额+时间匹配建议关联（linked_transaction_id），但不强制。P1 阶段仅预留字段，暂不实现自动匹配。

**理由**：
- 用户心智模型最简：只需关心"哪个账户"+"钱进还是钱出"，不需要同时思考两个账户
- 支持人际转账场景（小明、房东等），counterparty 不局限于系统内账户
- 单侧记录即有效，不存在配对一致性问题
- 统计报表中，转账（type=transfer）可以从收支总额中排除，避免虚增

**备选方案**：
- 单条双账户记录（account_id + to_account_id）——强制用户指定双端，增加交互复杂度，放弃
- 双条自动配对（系统自动生成对向记录）——引入一致性维护负担，且用户可能对"多出来的记录"感到困惑，放弃

### D6: 多币种——MVP 不支持，后续版本再加

**选择**：P1 阶段**不支持多币种**，所有金额默认人民币（CNY）。transactions 表保留 currency 字段（默认 CNY）为后续扩展预留，但 UI 不暴露币种选择。

**理由**：
- 行业调研：大多数记账软件特意避开多币种；现代支付（微信/支付宝）已自动转换本币
- 多币种涉及汇率 API、历史汇率精确性、复式记账等复杂问题，与 MVP 极简目标冲突
- 用户调研显示多币种属于低频需求，被列为"最无用功能"之一
- 有需求的用户可手动换算后以人民币记录

**备选方案**：
- 手动选择币种 + 仅存储——增加 UI 和数据模型复杂度但大多数用户用不到，推迟
- 后续可通过多账本功能（每个币种一个账本）替代

### D7: 草稿机制——推迟到 P2（语音模块）

**选择**：P1 阶段**不实现草稿机制**。transactions 表保留 is_draft 字段（默认 false）为 P2 预留，但 P1 不使用。

**理由**：
- 手动记账只需 2 步（选分类 + 输金额），几乎不存在"记一半退出"的场景
- 草稿需求的真实来源是 PRD 5.6 节的语音交互超时场景，属于 P2 范围
- 用户调研显示草稿不是刚性需求，用户更关心"快速记录"
- 移除草稿可避免 null 字段处理和草稿 UI 的额外复杂度

### D8: ID 策略——UUID v4

**选择**：所有实体主键使用 UUID v4（字符串存储）

**理由**：
- 本地生成，不依赖自增 ID，天然适配未来云同步场景（无 ID 冲突）
- 多设备独立创建记录时 ID 不会碰撞
- 使用 uuid 包生成

**备选方案**：
- 自增 INTEGER ID——多设备同步时会冲突，需要额外的 ID 映射层，放弃

### D9: 预设数据初始化——首次启动时播种

**选择**：在数据库首次创建时（migration version 1）通过 seed 脚本插入**1 个默认账户**（"钱包"）和预设分类（17 个，其中 15 个默认可见 + 2 个初始隐藏）。不预设多个账户。

**图标系统**：icon 字段使用带前缀的字符串格式，支持两种类型：

| 前缀 | 格式 | 示例 | 说明 |
|---|---|---|---|
| `material:` | `material:<icon_name>` | `material:restaurant` | Flutter Material Icons 名称，通过 `Icons` 类解析 |
| `emoji:` | `emoji:<emoji_char>` | `emoji:🍜` | Emoji 字符，直接渲染为 Text |

预设分类和默认账户使用 `material:` 图标（一致性好、矢量缩放），用户自定义分类/账户时可选择 Material Icons 或 emoji。

**颜色系统**：color 字段使用 8 位 ARGB hex 字符串，不含 `#` 前缀（例：`FF4CAF50` 表示不透明的绿色）。格式说明：
- 前 2 位 = Alpha 通道（FF = 不透明）
- 后 6 位 = RGB 值
- 与 Flutter 的 `Color(0xFFRRGGBB)` 构造函数直接对应，解析为 `Color(int.parse(colorHex, radix: 16))`
- 预设分类和默认账户使用莫兰迪色系（淡绿/淡蓝/暖灰），色值定义在常量文件中

**理由**：
- 行业调研结论：随手记的 8 类账户被用户普遍评价为"鸡肋"；TIMI 时光记账完全去掉账户概念；叨叨记账允许不设置资产直接记账
- 对语音记账场景，账户选择是多余的认知负担——用户说"午饭35"时不会想到"用什么账户"
- 仅初始化一个"钱包"默认账户，所有交易自动归入，用户无感
- 预设分类的 is_preset = true，阻止用户删除（但允许隐藏和重排序）
- Seed 数据定义在常量文件中，便于维护和国际化

### D10: 账户模块——渐进式披露（Progressive Disclosure）

**选择**：账户功能采用渐进式披露设计。MVP 默认**单账户体验**（用户完全不需要了解"账户"概念），多账户作为设置中的**可选增强功能**。

**设计分层**：

| 层级 | 体验 | 触发条件 |
|---|---|---|
| **默认体验** | 所有交易归入隐含的"钱包"账户，记账只需金额+分类（日期自动，描述可选） | 首次安装即是 |
| **主动开启** | 用户在设置中开启"多账户管理"后，可添加微信/支付宝/银行卡等 | 用户主动操作 |
| **语音智能**（P2） | NLP 自动识别"用微信付的"并关联账户，但不主动追问 | 语音中自然提及 |

**理由**：
- 用户心智负担最小化：新用户记账只需 2 个必填字段（金额、分类），日期自动填充今天，描述可选，不需要理解"什么是账户"
- 不阻碍高级用户：有资产管理需求的用户可自行开启多账户
- 对齐语音优先的产品定位：语音记账时不会被追问"用什么支付的"
- 行业验证：叨叨记账、鲨鱼记账均采用类似的"账户可选"策略

**多账户模式开关持久化**：使用 `shared_preferences`（Flutter 标准 key-value 存储）持久化多账户模式开关状态（key: `multi_account_enabled`, type: bool, default: false）。选择 shared_preferences 而非数据库表，因为：
- 开关类设置是轻量配置，不涉及关系查询
- 不需要同步到云端（各设备可独立配置）
- Flutter 社区标准方案，无额外依赖

**备选方案**：
- 预设 5 个账户（现金/银行卡/信用卡/微信/支付宝）——增加首次使用的认知负担，新用户面对 5 个不理解的选项，放弃
- 完全不支持多账户（如 TIMI）——过于激进，无法满足有资产管理需求的用户，放弃

### D11: 智能默认值——减少输入步骤

**选择**：通过智能默认值将记账操作简化到最少 2 步（选分类 + 输金额）。

**具体策略**：

| 字段 | 默认行为 | 用户可修改 |
|---|---|---|
| 日期 | 自动填充今天，提供"今天/昨天/前天"快捷按钮 | 可选改 |
| 描述 | 可选填，采用「Easy Capture, Smart Fallback」策略（见下方详述） | 可选填 |
| 分类排序 | 分层排序：① 最近使用 3 个分类显示在快捷区域 ② 时段推荐以高亮标记（不改变位置）③ 完整列表按用户手动 sort_order | 自动 |
| 账户 | 自动归入默认"钱包"账户 | 开启多账户后可选 |

**描述字段策略——「Easy Capture, Smart Fallback」**：

描述（description）本质上是触发记账行为的事件（"午饭"、"打车"），但行业最佳实践表明不应将其设为必填——每增加一个必填字段，记账完成率下降约 15-20%。正确做法是让系统足够聪明，使事件描述被"零摩擦"捕获：

| 输入方式 | 描述捕获策略 | 用户感知 |
|---|---|---|
| **语音输入**（P2） | NLP 自动提取描述，如 "午饭花了35" → description="午饭" | 零额外操作 |
| **手动输入** | 可选填；基于分类+时段+历史记录推荐常用描述（如选了"餐饮"且在中午 → 推荐"午饭"） | 一次点击选择 |
| **未填写** | Fallback 到分类名，如分类="餐饮" → description 展示为"餐饮" | 无感知 |
| **事后补充** | 历史交易允许编辑描述 | 主动操作 |

P1 阶段实现手动输入 + 未填写 Fallback；智能推荐和语音提取随对应模块迭代。

**时段推荐映射表**（定义在常量文件中，可后续扩展）：

| 时段 | 时间范围 | 推荐分类 | 推荐类型 |
|---|---|---|---|
| 早餐 | 06:00-09:00 | 餐饮 | 支出 |
| 午餐 | 11:00-13:00 | 餐饮 | 支出 |
| 晚餐 | 17:00-19:30 | 餐饮 | 支出 |
| 早通勤 | 07:00-09:00 | 交通 | 支出 |
| 晚通勤 | 17:00-19:00 | 交通 | 支出 |

注：同一时段可能匹配多个分类（如 17:00-19:00 同时匹配餐饮和交通），系统 SHALL 对所有匹配分类添加高亮标记。映射规则定义在 `lib/core/constants/` 中，不硬编码在业务逻辑中，便于后续根据用户行为数据调整。

**理由**：
- 行业最佳实践：松鼠记账 3 次点击完成记账；钱迹提供"今天/昨天/前天"快捷按钮
- 智能预判分类（基于时间段）比增加更多分类更有效
- 最近使用分类优先排序，让高频操作更快触达
- 描述可选而非必填：业界主流产品（钱迹、松鼠、叨叨、MOZE）均为可选，分类已提供事件的粗粒度抽象

### D12: 余额策略——流水视角优先，余额作为可选参考值

**选择**：默认体验以**流水视角**（时间段收支汇总）为核心，不展示账户余额。余额作为多账户模式下的可选参考值，且标注为"记账余额"（非真实余额）。

**设计分层**：

| 层级 | 余额处理 | 首页展示 |
|---|---|---|
| **默认单账户体验** | 不展示余额，用户无需理解余额概念 | 今日/本月收支汇总（"本月支出 ¥3,245"） |
| **多账户开启后** | 账户列表可展示"记账余额"（基于 initial_balance + 已记录交易计算），明确标注"基于已记录交易" | 同上，账户详情页可查看记账余额 |

**余额计算公式**（仅多账户模式下使用）：

```
记账余额 = initial_balance
         + SUM(income.amount)
         + SUM(transfer[direction=in].amount)
         - SUM(expense.amount)
         - SUM(transfer[direction=out].amount)
```

**理由**：

- **信任悖论**：余额准确性依赖"初始值正确 + 每笔交易都被记录"，两个条件在手动记账场景下几乎不可能同时满足；展示一个不准确的余额比不展示更糟
- **用户真实关注排序**：调研显示用户关注度为"花了多少 > 花在哪 > 趋势对比 > 预算剩余 >> 账户余额"，前四项均为流水视角、永远准确
- **行业验证**：钱迹展示"记账余额"并明确标注非真实余额；叨叨/松鼠完全不展示余额；随手记的完整余额管理因复杂度高导致新用户弃坑率高
- **对齐产品定位**：随口记定位为轻量级语音记账，"本月花了多少"比"我还有多少钱"更匹配目标用户群

**备选方案**：
- 始终展示余额（如随手记）——增加认知负担，且余额不准确时损害产品信任度，放弃
- 对接银行 API 自动同步余额（如 Money Forward）——国内银行接口不开放，技术不可行，放弃
- 完全不预留余额能力——过于激进，无法满足有资产管理需求的用户，放弃

## Risks / Trade-offs

| 风险 | 缓解措施 |
|---|---|
| drift 生成代码量大，编译时间可能变长 | 使用 build_runner 的 --delete-conflicting-outputs 避免冲突；开发期间用 watch 模式 |
| UUID 字符串主键比 INTEGER 占用更多存储和索引空间 | 记账 App 数据量有限（年均数千条），性能影响可忽略 |
| 预设分类翻译（国际化）需在 seed 数据中处理 | Seed 数据使用 i18n key，运行时通过 intl 解析为当前语言 |
| 转账单侧记录可能导致账户间余额不平衡 | 设计预期——用户自由选择记录哪一侧；后续版本可增加"建议补录对侧"提示 |
| counterparty 为自由文本，同一对方可能有多种写法 | P1 阶段不做归一化；后续可通过 NLP 或输入建议做模糊匹配 |
| 单账户默认体验下，用户无法区分支付方式 | 设计预期——MVP 优先极简体验；需要区分的用户可开启多账户功能 |
| linked_transaction_id 删除一侧后对向引用悬挂 | 不设 FK 约束，应用层在删除交易时清理对向记录的 linked_transaction_id（置 null） |

## Resolved Questions

审视过程中发现并已解决的设计问题和 PRD 对比遗漏：

| # | 问题 | 解决方案 | 关联决策 |
|---|---|---|---|
| Q1 | **description vs note 语义重叠** | 合并为单一 description 字段（事件描述 + 备注合一），移除 note 字段 | D4, D11 |
| Q2 | **自定义分类删除外键悬挂** | 条件策略：无引用时硬删除，有引用时软删除（is_hidden=true） | D4, category spec |
| Q3 | **date 字段精度歧义** | 明确为 DATE 类型（仅日期），存储为 YYYY-MM-DD 00:00:00 UTC | D4 |
| Q4 | **分类排序优先级冲突** | 分层不冲突：最近使用=快捷区域、时段推荐=高亮标记、手动排序=基准顺序 | D11, category spec |
| Q5 | **icon 字段格式未定义** | 带前缀字符串：`material:<name>` 或 `emoji:<char>`，预设使用 Material Icons | D4, D9 |
| Q6 | **多账户开关持久化缺失** | 使用 shared_preferences 存储（key: multi_account_enabled, default: false） | D10, account spec |
| Q7 | **分类"最近使用"追踪机制缺失** | 查询 transactions 表按 created_at DESC 取最近 N 条不重复 category_id，零额外存储 | D11, category spec |
| Q8 | **首页聚合查询未定义** | 在 transaction-query spec 中补充收支汇总和最近交易查询需求（转账不计入收支） | transaction-query spec |
| Q9 | **时段推荐映射不完整** | 补充 5 个时段映射（早/午/晚餐+早/晚通勤），定义在常量文件中可扩展 | D11, category spec |
| Q10 | **交易删除配对级联未定义** | 删除时对向记录的 linked_transaction_id 置 null | D5, transaction-recording spec |
| Q11 | **color 字段格式未定义** | 8 位 ARGB hex 不含 # 前缀（如 FF4CAF50），与 Flutter Color 构造函数直接对应 | D4, D9 |

## P3 数据就绪度评估

P1 数据模型（accounts / categories / transactions 三张表）对后续 P3（统计报表 + 预算功能）五项核心分析能力的支撑评估。

### 已就绪的分析能力（P1 数据模型完全支撑）

#### 1. 时间段收支汇总

- **展示条件**：无条件展示（首页核心体验）；零交易时总收入=0、总支出=0
- **数据前提**：transactions（type, amount, date, is_draft）
- **输出指标**：总收入 = SUM(income.amount)、总支出 = SUM(expense.amount)、净收支 = 总收入 - 总支出；转账不计入；仅统计 is_draft=false
- **P1 Spec 状态**：transaction-query spec 已定义（缺"净收支"派生指标，P3 补充）

#### 2. 支出分类占比

- **展示条件**：至少存在 1 笔支出交易；支持日/周/月/年维度；支持按账户筛选（多账户模式下）；支持收入/支出视角切换
- **数据前提**：transactions（type=expense, amount, category_id, date） + categories（name, icon, color）
- **输出指标**：各分类支出额 = SUM(amount) GROUP BY category_id、分类占比 = 分类支出额 / 时段总支出 × 100%、按金额降序排列
- **P1 Spec 状态**：未覆盖（P3 需新增聚合查询 spec）
- **PRD 付费属性**：基础图表（饼图）= 免费

#### 3. 与上期趋势对比

- **展示条件**：至少存在 2 个完整周期的数据；仅 1 个周期时展示当期、不展示变化率；需付费订阅（PRD 9.3）
- **数据前提**：transactions（type, amount, date）+ 当期与上期日期范围（业务层计算，如本月=2月 → 上月=1月）
- **输出指标**：当期收入/支出、上期收入/支出、收入变化率 = (当期-上期)/上期 × 100%、支出变化率同理、上期为零时展示"无上期数据"
- **P1 Spec 状态**：未覆盖（P3 需新增对比查询 spec + "上期"计算逻辑）
- **PRD 付费属性**：高级统计（趋势图/对比）= **付费**

#### 4. 账户余额汇总

- **展示条件**：仅 multi_account_enabled=true 时展示；标注"基于已记录交易"
- **数据前提**：accounts（initial_balance, is_archived） + transactions（account_id, type, amount, transfer_direction, is_draft）
- **输出指标**：单账户记账余额 = initial_balance + SUM(income+transfer_in) - SUM(expense+transfer_out)（仅 is_draft=false）；多账户总余额 = SUM(各活跃账户记账余额)（is_archived=true 不计入）
- **P1 Spec 状态**：单账户余额已定义；多账户总余额和归档账户处理未定义（P3 补充）

### 需要扩展数据模型的分析能力

#### 5. 预算剩余计算

- **展示条件**：仅在用户设置了至少 1 个分类预算时展示；80% 触发预警、100% 触发超支通知
- **数据前提**：**需新增 budgets 表**（P1 无此表） + transactions（type=expense, amount, category_id, date）
- **输出指标**：预算金额、当月实际消费 = SUM(expense.amount WHERE category_id=X AND date IN current_month)、预算剩余 = 预算额 - 实际消费、使用率 = 实际消费/预算额 × 100%
- **P1 Spec 状态**：完全未覆盖
- **P3 所需工作**：drift migration 新增 budgets 表 + 预算 CRUD spec + 消费聚合 spec + 预警规则 spec
- **不在 P1 预留的理由**：budgets 是独立实体，不影响现有表结构；新增表通过 migration 无破坏性完成；空表预留增加认知负担且无实际价值
- **PRD 付费属性**：预算管理 = 免费

### P3 Spec 编写参考——关键指标公式汇总

| 指标 | 公式 | 免费/付费 |
|---|---|---|
| 净收支 | 总收入 - 总支出（转账不计入） | 免费 |
| 分类占比 | 分类支出额 / 时段总支出 × 100% | 免费 |
| 收支变化率 | (当期 - 上期) / 上期 × 100%，上期=0 时降级展示 | 付费 |
| 预算使用率 | 当月分类实际支出 / 分类预算额 × 100%，≥80% 预警、≥100% 超支 | 免费 |
| 单账户记账余额 | initial_balance + Σ(income+transfer_in) - Σ(expense+transfer_out)，仅 is_draft=false | 免费 |
| 多账户总余额 | Σ(各活跃账户记账余额)，is_archived=true 不计入 | 免费 |