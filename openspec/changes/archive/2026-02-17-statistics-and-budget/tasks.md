## 1. 数据库迁移与预算表

- [x] 1.1 新增 `Budgets` 表定义并升级 schema version 1→2（migration strategy 中新增 `onUpgrade`）
  - `voice-note-client/lib/core/database/app_database.dart`
- [x] 1.2 运行 drift 代码生成（`build_runner`），验证生成的 `.g.dart` 文件
  - `voice-note-client/lib/core/database/app_database.g.dart`
- [x] 1.3 编写数据库迁移测试（v1→v2 升级后 budgets 表可用、现有数据不丢失）
  - `voice-note-client/test/core/database/migration_test.dart`

## 2. 统计数据层

- [x] 2.1 创建 `StatisticsDao`：分类汇总查询、每日/每月趋势查询、时间段收支总额查询
  - `voice-note-client/lib/features/statistics/data/statistics_dao.dart`
- [x] 2.2 创建 `StatisticsRepository`：封装 DAO，返回领域模型
  - `voice-note-client/lib/features/statistics/data/statistics_repository.dart`
- [x] 2.3 创建领域模型：`CategorySummary`、`PeriodSummary`、`TrendPoint`
  - `voice-note-client/lib/features/statistics/domain/models/category_summary.dart`
  - `voice-note-client/lib/features/statistics/domain/models/period_summary.dart`
  - `voice-note-client/lib/features/statistics/domain/models/trend_point.dart`
- [x] 2.4 编写 StatisticsDao 单元测试（内存数据库，验证各聚合查询正确性）
  - `voice-note-client/test/features/statistics/data/statistics_dao_test.dart`

## 3. 预算数据层

- [x] 3.1 创建 `BudgetDao`：CRUD + 按月份查询 + upsert
  - `voice-note-client/lib/features/budget/data/budget_dao.dart`
- [x] 3.2 创建 `BudgetRepository`：封装 DAO，提供预算继承逻辑（自动复制上月配置）
  - `voice-note-client/lib/features/budget/data/budget_repository.dart`
- [x] 3.3 创建领域模型：`BudgetStatus`（预算状态枚举：normal/warning/exceeded）
  - `voice-note-client/lib/features/budget/domain/models/budget_status.dart`
- [x] 3.4 编写 BudgetDao 单元测试
  - `voice-note-client/test/features/budget/data/budget_dao_test.dart`

## 4. 预算领域层

- [x] 4.1 创建 `BudgetService`：预算检查逻辑（80%/100% 阈值）、通知去重、本地通知集成
  - `voice-note-client/lib/features/budget/domain/budget_service.dart`
- [x] 4.2 集成 `flutter_local_notifications`：初始化、权限请求、通知发送
  - `voice-note-client/lib/core/notifications/notification_service.dart`
- [x] 4.3 在交易保存流程（`VoiceSessionNotifier`、`TransactionFormScreen`）中接入异步预算检查
  - `voice-note-client/lib/features/voice/presentation/providers/voice_session_provider.dart`
  - `voice-note-client/lib/features/transaction/presentation/screens/transaction_form_screen.dart`
- [x] 4.4 编写 BudgetService 单元测试（阈值检查、去重逻辑）
  - `voice-note-client/test/features/budget/domain/budget_service_test.dart`

## 5. 统计页 UI

- [x] 5.1 添加 `fl_chart` 依赖到 `pubspec.yaml`
  - `voice-note-client/pubspec.yaml`
- [x] 5.2 创建 `PeriodSelector` 组件（日/周/月/年 SegmentedButton + 左右翻页）
  - `voice-note-client/lib/features/statistics/presentation/widgets/period_selector.dart`
- [x] 5.3 创建 `PieChartWidget`（分类饼图，支持支出/收入切换，Top 10 + 其他合并）
  - `voice-note-client/lib/features/statistics/presentation/widgets/pie_chart_widget.dart`
- [x] 5.4 创建 `BarChartWidget`（收支柱状图，支持多维度）
  - `voice-note-client/lib/features/statistics/presentation/widgets/bar_chart_widget.dart`
- [x] 5.5 创建 `TrendChartWidget`（趋势折线图，双线收入/支出）
  - `voice-note-client/lib/features/statistics/presentation/widgets/trend_chart_widget.dart`
- [x] 5.6 创建 `CategoryRanking` 组件（分类排行榜，点击跳转交易列表）
  - `voice-note-client/lib/features/statistics/presentation/widgets/category_ranking.dart`
- [x] 5.7 创建 `StatisticsScreen`（主页面，Tab 切换图表 + 排行榜 + 收支总览 + 同期对比 + 账户筛选）
  - `voice-note-client/lib/features/statistics/presentation/screens/statistics_screen.dart`
- [x] 5.8 创建 `StatisticsProviders`（Riverpod providers 连接 Repository 和 UI）
  - `voice-note-client/lib/features/statistics/presentation/providers/statistics_providers.dart`
- [x] 5.9 编写统计页 Widget 测试
  - `voice-note-client/test/features/statistics/presentation/screens/statistics_screen_test.dart`

## 6. 预算页 UI

- [x] 6.1 创建 `BudgetProgressBar` 组件（带颜色渐变的进度条）
  - `voice-note-client/lib/features/budget/presentation/widgets/budget_progress_bar.dart`
- [x] 6.2 创建 `BudgetOverviewScreen`（预算概览页，汇总 + 各分类进度）
  - `voice-note-client/lib/features/budget/presentation/screens/budget_overview_screen.dart`
- [x] 6.3 创建 `BudgetEditScreen`（预算编辑页，批量设置分类预算）
  - `voice-note-client/lib/features/budget/presentation/screens/budget_edit_screen.dart`
- [x] 6.4 创建 `BudgetProviders`
  - `voice-note-client/lib/features/budget/presentation/providers/budget_providers.dart`
- [x] 6.5 编写预算页 Widget 测试
  - `voice-note-client/test/features/budget/presentation/screens/budget_overview_screen_test.dart`

## 7. 导航与集成

- [x] 7.1 更新 `AppShell`：底部导航从 3 Tab 改为 4 Tab（首页/统计/明细/设置），调整 FAB 位置
  - `voice-note-client/lib/shared/widgets/app_shell.dart`
- [x] 7.2 更新 `router.dart`：新增 `/statistics`、`/settings/budget`、`/settings/budget/edit` 路由
  - `voice-note-client/lib/app/router.dart`
- [x] 7.3 更新 `HomeScreen`：新增预算进度摘要卡片
  - `voice-note-client/lib/features/home/presentation/screens/home_screen.dart`
- [x] 7.4 更新 `SettingsScreen`：新增"预算设置"入口
  - `voice-note-client/lib/features/settings/presentation/screens/settings_screen.dart`
- [x] 7.5 更新 `AppDatabase`：注册 `BudgetDao`、`StatisticsDao`
  - `voice-note-client/lib/core/database/app_database.dart`
- [x] 7.6 更新 `app_shell_test.dart` 和 `router_test.dart` 适配新导航结构
  - `voice-note-client/test/shared/widgets/app_shell_test.dart`
  - `voice-note-client/test/app/router_test.dart`

## 8. 交易列表筛选参数支持

- [x] 8.1 更新 `router.dart`：`/transactions` 路由支持 query params（categoryId、dateFrom、dateTo）
  - `voice-note-client/lib/app/router.dart`
- [x] 8.2 更新 `TransactionListScreen`：从路由读取筛选参数并自动应用
  - `voice-note-client/lib/features/transaction/presentation/screens/transaction_list_screen.dart`
- [x] 8.3 编写筛选参数路由测试
  - `voice-note-client/test/features/transaction/presentation/screens/transaction_list_screen_test.dart`

## 9. 全量测试与回归

- [x] 9.1 运行全量客户端测试，确保零回归（416 通过）
- [x] 9.2 运行全量服务端测试，确保零回归（31 通过，无代码变更）
