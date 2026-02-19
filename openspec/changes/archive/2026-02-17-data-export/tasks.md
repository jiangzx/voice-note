## 1. 依赖与项目配置

- [x] 1.1 在 `voice-note-client/pubspec.yaml` 添加依赖：`csv`、`excel`、`share_plus`（`path_provider` 已存在）
- [x] 1.2 创建 `voice-note-client/lib/features/export/` 目录结构（data/domain/presentation）

## 2. Domain 层 — 模型与接口

- [x] 2.1 创建 `voice-note-client/lib/features/export/domain/export_config.dart` — ExportConfig 模型（format、dateFrom、dateTo、transactionType、categoryIds、accountIds）
- [x] 2.2 创建 `voice-note-client/lib/features/export/domain/export_strategy.dart` — ExportStrategy 抽象接口（fileExtension、mimeType、export 方法）
- [x] 2.3 创建 `voice-note-client/lib/features/export/domain/export_service.dart` — ExportService 编排查询、导出、分享流程；分批查询（500条/批）；进度回调；取消支持

## 3. Data 层 — 格式实现

- [x] 3.1 创建 `voice-note-client/lib/features/export/data/csv_export_strategy.dart` — CSV 格式实现（UTF-8 BOM、中文列标题、日期/金额格式化）
- [x] 3.2 创建 `voice-note-client/lib/features/export/data/xlsx_export_strategy.dart` — Excel 格式实现（交易明细 Sheet + 分类汇总 Sheet）

## 4. Data 层 — 批量查询

- [x] 4.1 在 `voice-note-client/lib/features/transaction/data/transaction_dao.dart` 新增 `getFilteredBatch` 方法 — 支持 offset/limit 分页、日期范围、类型、分类、账户筛选
- [x] 4.2 在 `voice-note-client/lib/features/transaction/data/transaction_dao.dart` 新增 `getFilteredCount` 方法 — 查询符合条件的总记录数

## 5. Presentation 层 — Providers

- [x] 5.1 创建 `voice-note-client/lib/features/export/presentation/providers/export_providers.dart` — Riverpod providers（exportServiceProvider、exportStrategyProvider）

## 6. Presentation 层 — 导出选项 Sheet

- [x] 6.1 创建 `voice-note-client/lib/features/export/presentation/widgets/export_options_sheet.dart` — Bottom Sheet 组件（格式选择、时间范围选择器、类型筛选、分类多选、确认导出按钮）

## 7. Presentation 层 — 导出进度对话框

- [x] 7.1 创建 `voice-note-client/lib/features/export/presentation/widgets/export_progress_dialog.dart` — 进度对话框（已导出/总数、进度条、取消按钮、完成后分享按钮）

## 8. 集成 — 设置页入口

- [x] 8.1 修改 `voice-note-client/lib/features/settings/presentation/screens/settings_screen.dart` — 在"预算管理"之后添加"数据导出"入口项

## 9. 集成 — 明细页导出按钮

- [x] 9.1 修改 `voice-note-client/lib/features/transaction/presentation/screens/transaction_list_screen.dart` — AppBar 添加导出图标按钮，传递当前筛选条件至导出 Sheet

## 10. 单元测试

- [x] 10.1 创建 `voice-note-client/test/features/export/data/csv_export_strategy_test.dart` — 测试 CSV 格式、BOM、中文列标题、金额格式、空数据处理
- [x] 10.2 创建 `voice-note-client/test/features/export/data/xlsx_export_strategy_test.dart` — 测试 XLSX 双 Sheet 结构、汇总计算、空数据处理
- [x] 10.3 创建 `voice-note-client/test/features/export/domain/export_service_test.dart` — 测试分批查询逻辑、进度回调、取消操作、空结果处理
- [x] 10.4 创建 `voice-note-client/test/features/transaction/data/transaction_dao_export_test.dart` — 测试 getFilteredBatch、getFilteredCount 筛选和分页正确性

## 11. 全量测试验证

- [x] 11.1 运行 `flutter test` 确认全部测试通过，零回归
