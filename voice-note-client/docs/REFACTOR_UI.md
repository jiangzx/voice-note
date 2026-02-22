# 亮白极简 UI 重构说明

## 主题与模式

- **亮色主题**：`lib/app/theme.dart` 中 `buildLightTheme()` 实现规范中的全量颜色、圆角、组件主题；`app.dart` 使用 `theme: buildLightTheme()`。
- **主题**：仍通过设置页的「主题」切换；`darkTheme` 使用原有 `buildTheme(seedColor, Brightness.dark)`，未按亮白规范重做。
- **主题色**：设置页「主题色」仍可切换 seed，仅影响深色主题；亮色主题固定使用规范色（#1677FF 等）。

## 设计令牌与组件

- **design_tokens.dart**：新增 `AppRadius.card`（20）、`AppRadius.input`（28）、`AppShadow.card` / `AppShadow.input`（轻阴影）。
- **theme.dart**：`AppColors` 语义色、`TransactionColors` 亮色值（收入 #00B42A、支出 #F53F3F、转账 #1677FF）、`buildLightTheme()` 及 ColorScheme/AppBar/Card/Input/ListTile/FAB/NavigationBar/SegmentedButton 主题。
- **design_system/**：`EntryButton`、`InputActionBar`、`DataCard`/`DataCardItem`、`AppListTile`、`PrimaryButton`、`SecondaryButton`（底部导航通过 `NavigationBarThemeData` 统一，未单独封装）。

## 已重构页面与组件

| 区域 | 修改内容 |
|------|----------|
| 壳层 | AppShell：FAB 品牌色+白字，NavigationBar 由主题控制 |
| FAB | AnimatedVoiceFab、HomeFab：品牌色 / 浅灰白+深灰字 |
| 首页 | VoiceFeatureCard 浅灰白卡片+线性图标；SummaryCard、_BudgetSummaryCard 浅灰白+轻阴影；RecentTransactionTile、左滑删除、选择栏 规范色 |
| 语音页 | 整页白底；语音监听区浅灰白卡片；PushToTalk/语音动画 品牌色/红；ModeSwitcher 由主题控制；退出 FAB 浅灰白；键盘输入栏圆角+占位色 |
| 明细页 | TransactionListScreen 选择栏/筛选提示；TransactionTile、DailyGroupHeader 规范色与背景 |
| 统计/设置 | 使用 ThemeData 的 colorScheme，已与亮色主题一致 |
| 共用 | EmptyStateWidget、ErrorStateWidget、batch_confirmation_card 等 使用 AppColors |

## 运行验证

1. **编译**：`flutter pub get && flutter run`（iOS 或 Android）。
2. **建议检查**：
   - 首页：语音卡片、本月收支、预算卡片、最近交易列表、底部导航与 FAB 为白/浅灰白+品牌蓝，无深色块。
   - 语音页：进入/退出、自动/手动/键盘切换、录音与确认流程正常；界面为白底与浅灰白卡片。
   - 明细页：筛选、长按多选、左滑删除、跳转编辑正常。
   - 统计/设置：图表与列表为规范绿/红/灰，导航与开关正常。
3. **业务**：未改动 provider、router、data 层或原生接口；仅替换 UI 与 theme 引用。

## 未改范围

- 深色主题未按亮白规范重做，仅保留原 seed 生成样式。
- 部分对话框、二级页（如分类管理、账户管理、预算编辑）仍主要依赖 Material 主题，未逐一手动替换为 AppColors，但会随 `theme.colorScheme` 在亮色下一致。
