## Context

当前系统支持在 App 内查看交易记录和统计图表，但不支持数据导出。用户无法将数据传输到 Excel、财务软件或其他平台。本功能为纯客户端实现，不涉及服务端改动。

现有数据层（`TransactionDao`）已支持按日期范围、分类、账户等条件查询交易记录，可直接复用。

## Goals / Non-Goals

**Goals:**
- 支持 CSV 和 Excel（XLSX）两种导出格式
- 支持按时间范围、分类、账户筛选导出数据
- 通过系统 Share Sheet 分享导出文件
- 大数据量导出时提供进度反馈
- 从设置页和明细页两个入口发起导出

**Non-Goals:**
- 云端导出/同步（Phase 5 范围）
- PDF 报表生成（低频需求，延后考虑）
- 导入功能（反向操作，独立 change 处理）
- 导出预算/统计数据（仅导出交易明细）

## Decisions

### D1: 导出格式库选型

**决定**：CSV 使用 `csv` 包，Excel 使用 `excel` 包。

**替代方案**：
- `syncfusion_flutter_xlsio`：功能更强但体积大（+5MB）、需要 license
- 纯 CSV 不加 Excel：用户反馈 Excel 格式需求强（带格式更易阅读）

**理由**：`csv` 和 `excel` 均为纯 Dart 实现，零原生依赖，包体积小（<200KB），满足基本需求。

### D2: 导出架构 — Strategy 模式

**决定**：定义 `ExportStrategy` 抽象接口，CSV 和 XLSX 分别实现。

```dart
abstract class ExportStrategy {
  String get fileExtension;
  String get mimeType;
  Future<File> generate(List<ExportRow> rows, ExportConfig config);
}
```

ExportService 负责分批查询（500 条/批），将 `TransactionEntity` 转换为 `ExportRow`（平面化 DTO），累积全部行后传给 `ExportStrategy.generate()`。XLSX 库（`excel`）要求一次性写入所有数据，因此无法真正流式写入；CSV 理论上可追加写入，但为统一接口和简化实现，均采用全量传递。内存控制通过 `ExportRow`（轻量 DTO，约 200 bytes/条）实现，10 万条约 20MB，在移动设备可接受范围内。

**理由**：未来可扩展 JSON、PDF 等格式，符合开闭原则。

### D3: 大数据量处理

**决定**：分批查询 + Stream 式写入。每批 500 条，避免一次性加载全部数据到内存。

**替代方案**：
- 全量加载：简单但 10 万条记录可能 OOM
- Isolate 后台处理：增加复杂度，且 drift 不支持跨 Isolate 共享数据库连接

**理由**：分批查询在主 Isolate 运行但内存可控（峰值 ~500 条），Drift 的 `limit/offset` 查询效率足够。UI 线程阻塞可接受（文件 I/O 已异步），用户体验通过进度对话框保证。

### D4: 文件分享方案

**决定**：使用 `share_plus` 包，导出文件写入临时目录后通过系统 Share Sheet 分享。

**理由**：`share_plus` 是 Flutter 官方推荐的分享方案，跨平台支持好。文件写入 `getTemporaryDirectory()` 后分享，系统会在合适时机自动清理。

### D5: 导出入口

**决定**：两个入口 —— ①设置页"数据导出"项（全量导出），②明细页 AppBar 导出按钮（导出当前筛选结果）。

**理由**：设置页入口覆盖"备份"场景，明细页入口覆盖"分享当前查看的数据"场景。

### D6: Excel 格式设计

**决定**：XLSX 文件包含两个 Sheet：
- **交易明细** Sheet：日期、时间、类型、分类、金额、账户、备注（与 CSV 列一致）
- **汇总** Sheet：按分类汇总的收支合计

**理由**：两个 Sheet 提供明细和概览双视角，是财务导出的常见模式。

## Directory Structure

```
voice-note-client/lib/features/export/
├── data/
│   ├── csv_export_strategy.dart      # CSV format implementation
│   └── xlsx_export_strategy.dart     # Excel format implementation
├── domain/
│   ├── export_strategy.dart          # Abstract strategy interface
│   ├── export_config.dart            # Export configuration model
│   └── export_service.dart           # Orchestrates query + export + share
└── presentation/
    ├── providers/
    │   └── export_providers.dart     # Riverpod providers
    └── widgets/
        ├── export_options_sheet.dart  # Bottom sheet for export settings
        └── export_progress_dialog.dart # Progress dialog during export
```

## Risks / Trade-offs

- **[内存]** 大量数据导出可能阻塞 UI → 分批查询（500条/批）控制峰值内存，进度对话框保证用户感知
- **[编码]** CSV 中文在某些 Excel 版本中乱码 → 使用 UTF-8 BOM 前缀解决
- **[权限]** Android 10+ Scoped Storage 限制直接文件访问 → 使用 share_plus 通过 Content Provider 分享，无需存储权限
- **[格式]** `excel` 包不支持复杂格式（合并单元格、公式） → 当前需求仅需基本格式，足够使用

## Open Questions

- 无（功能边界清晰，技术方案确定）
