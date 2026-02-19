## Context

数据层和领域层已完整实现，包括：
- **账户**：`AccountRepository` + Riverpod providers（`accountListProvider`、`defaultAccountProvider`、`multiAccountEnabledProvider`）
- **分类**：`CategoryRepository` + providers（`visibleCategoriesProvider`、`recentCategoriesProvider`、`recommendedCategoryNamesProvider`）
- **交易**：`TransactionRepository` + providers（`transactionListProvider`、`summaryProvider`、`recentTransactionsProvider`、`dailyGroupedProvider`）+ `TransactionForm` StateNotifier

当前 App 仅有占位页面（`_PlaceholderHome`），路由仅一条 `/`。本次需将已有数据能力完整映射为可交互 UI。

约束：
- 纯本地运行，无网络请求
- 所有 provider 已就绪，UI 层只需 `ref.watch()` 消费
- Material 3 + teal 色系（已在 `app.dart` 中配置）
- 不新增外部依赖

## Goals / Non-Goals

**Goals:**

- 实现 4 个核心页面：首页、记账、明细列表、设置
- 复用已有 provider 层，UI 仅负责渲染和交互转发
- 遵循 Feature-First 结构，每个页面作为对应 feature 的 presentation 层扩展
- 统一的 Material 3 视觉语言与交互模式
- 关键页面的 Widget 测试覆盖

**Non-Goals:**

- 不实现语音输入（P2 范围）
- 不实现统计报表/图表（P3 范围）
- 不实现数据导出（P4 范围）
- 不实现云同步/登录（P5 范围）
- 不修改已有数据层/领域层逻辑
- 不做自定义动画或高度定制化主题

## Decisions

### D1: 导航架构 — BottomNavigationBar + ShellRoute

采用 `go_router` 的 `ShellRoute` 包裹三个一级页面（首页 / 明细列表 / 设置），底部导航栏切换。记账页面作为全屏模态路由（`context.push`）而非 Tab 页。

**方案对比：**
| 方案 | 优点 | 缺点 |
|------|------|------|
| **ShellRoute + BottomNav（选用）** | 原生 Material 3 模式；Tab 状态天然保持；go_router 官方推荐 | 需要 ShellRoute 配置 |
| Drawer 侧边栏 | 可容纳更多入口 | 记账类工具 App 交互过重；不符合主流习惯 |
| PageView + 手势滑动 | 滑动切换流畅 | 页面少（3个）时意义不大；与 FAB 手势冲突 |

**路由结构：**
```
/                     → ShellRoute (底部导航)
├── /home             → HomeScreen (Tab 0, 首页)
├── /transactions     → TransactionListScreen (Tab 1, 明细)
└── /settings         → SettingsScreen (Tab 2, 设置)

/record               → TransactionFormScreen (全屏 push, 新建)
/record/:id           → TransactionFormScreen (全屏 push, 编辑)
/settings/accounts    → AccountManageScreen
/settings/categories  → CategoryManageScreen
```

### D2: 记账入口 — FAB 悬浮按钮

首页和明细列表页的右下角放置 FAB（`FloatingActionButton`），点击跳转记账页面。

**理由：** 记账是最高频操作，FAB 是 Material 3 对"主要动作"的标准表达。FAB 仅在首页和明细列表页展示，设置页不展示（设置页无记账语境）。

### D3: 金额输入 — 自定义数字键盘

自定义底部数字键盘（0-9 + 小数点 + 退格），显示在记账页面底部区域，取代系统键盘。

**方案对比：**
| 方案 | 优点 | 缺点 |
|------|------|------|
| **自定义数字键盘（选用）** | 按键更大、误触少；可定制布局；不遮挡上方内容 | 需自行实现 |
| 系统软键盘 | 无需开发 | 按键小；弹出时遮挡内容；收起/弹出体验不流畅 |

键盘布局（4×3 网格）：
```
[ 7 ] [ 8 ] [ 9 ]
[ 4 ] [ 5 ] [ 6 ]
[ 1 ] [ 2 ] [ 3 ]
[ . ] [ 0 ] [ ⌫ ]
```

金额以字符串方式在 UI 层管理（避免浮点精度问题），仅在保存时转为 `double`。限制：最多 2 位小数，最大 99999999.99。

### D4: 分类选择 — 网格布局 + 分区展示

分类选择区域位于记账页面上半部分（键盘上方），采用可滚动网格布局：

1. **最近使用快捷区**（条件展示）：横向排列最近 3 个分类 chip，仅在有交易历史时展示
2. **完整分类网格**：4 列网格，每项显示图标 + 名称，时段推荐分类带高亮标记（`Badge` 或底色区分）

**切换逻辑：** 顶部 `SegmentedButton` 切换支出/收入。选择"转账"类型时隐藏分类区域。

### D5: 表单状态管理 — 复用 TransactionForm StateNotifier

直接复用已有的 `TransactionForm`（`transactionFormProvider`），UI 通过 `ref.watch` 读取状态、通过 Notifier 方法更新。新建时调用 `reset()`，编辑时从 Entity 回填。

不引入额外的 form 状态管理方案（如 flutter_form_builder），保持依赖精简。

### D6: 明细列表 — Sticky Header 按日分组

采用 `CustomScrollView` + `SliverList` 实现按日分组列表，每组头部显示日期和当日收支小计。使用 `dailyGroupedProvider` 获取数据。

筛选 UI 采用顶部 `FilterChip` 横向列表（日期范围快捷选项 + 类型筛选）+ 搜索栏。展开高级筛选（分类/金额范围/账户）通过 BottomSheet 实现。

### D7: 设置页面 — 简洁 ListView

设置页面采用 `ListView` + `ListTile` 布局：
- 多账户开关（`SwitchListTile`）
- 账户管理入口（多账户模式开启后才可见）
- 分类管理入口

账户管理和分类管理各自推进到独立子页面。

### D8: 主题配置 — 抽取到独立 theme.dart

将 `ThemeData` 配置从 `app.dart` 抽取到 `lib/app/theme.dart`，定义 light 主题（P1 仅 light 模式）。包含：
- `ColorScheme.fromSeed(seedColor: Colors.teal)` — Material 3 自适应色板
- 金额数字字体配置（`titleLarge` 用于显示金额）
- 收入色（绿色系）/ 支出色（红色系）/ 转账色（蓝色系）语义色扩展

### D9: 目录结构

```
lib/
├── app/
│   ├── app.dart                  # MaterialApp + router 引用
│   ├── router.dart               # GoRouter 完整路由定义
│   └── theme.dart                # ThemeData + 语义色扩展
├── features/
│   ├── home/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           ├── summary_card.dart
│   │           └── recent_transaction_tile.dart
│   ├── transaction/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── transaction_form_screen.dart
│   │       │   └── transaction_list_screen.dart
│   │       └── widgets/
│   │           ├── amount_display.dart
│   │           ├── number_pad.dart
│   │           ├── category_grid.dart
│   │           ├── category_chip.dart
│   │           ├── date_quick_select.dart
│   │           ├── type_selector.dart
│   │           ├── transfer_fields.dart
│   │           ├── transaction_tile.dart
│   │           ├── daily_group_header.dart
│   │           └── filter_bar.dart
│   ├── account/
│   │   └── presentation/
│   │       └── screens/
│   │           └── account_manage_screen.dart
│   └── category/
│       └── presentation/
│           └── screens/
│               └── category_manage_screen.dart
└── shared/
    └── widgets/
        └── app_shell.dart          # ShellRoute scaffold (BottomNav)
```

## Risks / Trade-offs

**[自定义数字键盘维护成本]** → 一次性投入约 150 行代码，布局简单（4×3 Grid），后续几乎无需修改。收益（大按键、不遮挡内容）远超成本。

**[TransactionForm 编辑回填复杂度]** → 编辑模式需从 Entity 回填到 FormState。通过在 `TransactionForm` 中新增 `loadFromEntity(TransactionEntity)` 方法解决，不影响已有 reset 逻辑。

**[Sticky Header 性能]** → 大量交易时 Sliver 渲染可能卡顿。P1 阶段数据量有限（纯本地手动记账），暂不做分页/虚拟化。后续可通过 `dailyGroupedProvider` 的日期范围参数实现按需加载。

**[分类管理排序 UI]** → 拖拽排序（`ReorderableListView`）实现成本低，但需小心触摸冲突。使用 Flutter 内置 `ReorderableListView.builder` 即可。

## Open Questions

（无——所有技术决策已在上方明确，spec 需求清晰，无需额外澄清）
