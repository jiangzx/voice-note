## Why

用户积累了大量记账数据后，需要一种方式将数据导出到外部工具（Excel、财务软件）进行深度分析、报税或备份。当前系统仅支持 App 内查看，无法满足数据可移植性需求。数据导出是记账类 App 的核心功能之一，直接影响用户留存和信任度（"我的数据我能带走"）。

## What Changes

- 新增 CSV 导出功能：支持将交易记录按时间范围导出为 CSV 文件
- 新增 Excel (XLSX) 导出功能：支持带格式的 Excel 导出，包含汇总 sheet
- 支持导出筛选：按时间范围、分类、账户筛选导出内容
- 支持系统分享：导出后通过系统 Share Sheet 分享文件（邮件、微信、云盘等）
- 导出进度提示：大量数据导出时展示进度，导出完成后提供分享操作

## Capabilities

### New Capabilities
- `data-export`: 数据导出功能，涵盖 CSV/Excel 格式生成、筛选条件、文件分享、导出进度

### Modified Capabilities
- `settings-screen`: 新增"数据导出"入口
- `transaction-list-screen`: 在明细页添加导出按钮，支持将当前筛选结果导出

## Impact

- **客户端新增依赖**：`csv`（CSV 生成）、`excel`（XLSX 生成）、`share_plus`（系统分享）；`path_provider` 已存在
- **客户端新增模块**：`features/export/`（data + domain + presentation）
- **数据层**：复用现有 `TransactionDao` 查询接口，新增批量查询方法（带分页以控制内存）
- **UI 层**：导出设置 Sheet（格式选择、时间范围、筛选条件）+ 导出进度对话框
- **服务端**：无变更（纯客户端功能）
- **存储**：导出文件使用系统临时目录，分享后自动清理
