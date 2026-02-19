## ADDED Requirements

### Requirement: 导出格式支持
系统 SHALL 支持将交易记录导出为 CSV 和 Excel（XLSX）两种格式。CSV 文件 SHALL 使用 UTF-8 编码并包含 BOM 前缀以确保中文兼容性。XLSX 文件 SHALL 包含"交易明细"和"分类汇总"两个 Sheet。

#### Scenario: 导出为 CSV
- **WHEN** 用户选择 CSV 格式导出
- **THEN** 系统 SHALL 生成 UTF-8 with BOM 编码的 CSV 文件，列包含：日期、类型、分类、金额、账户、备注

#### Scenario: 导出为 Excel
- **WHEN** 用户选择 Excel 格式导出
- **THEN** 系统 SHALL 生成 XLSX 文件，"交易明细" Sheet 包含全部交易记录（列与 CSV 一致：日期、时间、类型、分类、金额、账户、备注），"分类汇总" Sheet 包含按分类汇总的收支合计

#### Scenario: Excel 汇总 Sheet 内容
- **WHEN** 导出数据包含多个分类的支出和收入
- **THEN** "分类汇总" Sheet SHALL 展示每个分类的名称、类型（收入/支出）和金额合计

### Requirement: 导出筛选条件
系统 SHALL 支持按条件筛选导出内容。筛选条件 SHALL 包含：时间范围（起止日期）、交易类型（全部/支出/收入）、分类（可多选）、账户（可多选）。未设置筛选条件时 SHALL 导出全部数据。

#### Scenario: 按时间范围导出
- **WHEN** 用户设置时间范围为 2026-01-01 至 2026-01-31
- **THEN** 系统 SHALL 仅导出该日期范围内的交易记录

#### Scenario: 按分类筛选导出
- **WHEN** 用户选择仅导出"餐饮"和"交通"分类
- **THEN** 系统 SHALL 仅导出属于这两个分类的交易记录

#### Scenario: 按交易类型筛选
- **WHEN** 用户选择仅导出"支出"类型
- **THEN** 系统 SHALL 仅导出支出类型的交易记录

#### Scenario: 无筛选条件
- **WHEN** 用户未设置任何筛选条件即开始导出
- **THEN** 系统 SHALL 导出数据库中全部交易记录

### Requirement: 导出文件命名
系统 SHALL 按规则自动生成导出文件名。文件名格式 SHALL 为 `随口记_YYYYMMDD_HHmmss.{csv|xlsx}`。文件名 SHALL 包含导出时的时间戳以避免重名。

#### Scenario: 文件名格式
- **WHEN** 用户于 2026-02-17 14:30:00 导出 CSV
- **THEN** 文件名 SHALL 为 `随口记_20260217_143000.csv`

### Requirement: 导出进度反馈
系统 SHALL 在导出过程中提供进度反馈。SHALL 展示已处理记录数和总记录数。导出完成后 SHALL 提供分享操作入口。用户 SHALL 可在导出过程中取消操作。

#### Scenario: 展示导出进度
- **WHEN** 系统正在导出 1000 条记录，已处理 500 条
- **THEN** 系统 SHALL 展示"已导出 500/1000 条"进度信息

#### Scenario: 导出完成
- **WHEN** 导出成功完成
- **THEN** 系统 SHALL 展示完成状态并提供"分享"按钮

#### Scenario: 取消导出
- **WHEN** 用户在导出过程中点击取消
- **THEN** 系统 SHALL 停止导出、删除已生成的临时文件并关闭进度对话框

### Requirement: 文件分享
导出完成后，系统 SHALL 通过系统分享功能（Share Sheet）发送文件。分享 SHALL 支持邮件、即时通讯、云盘等系统级分享目标。分享后临时文件 SHALL 由系统自动清理。

#### Scenario: 分享导出文件
- **WHEN** 用户点击导出完成后的"分享"按钮
- **THEN** 系统 SHALL 调用系统 Share Sheet，文件以附件形式可分享到任意支持的 App

#### Scenario: 临时文件清理
- **WHEN** 导出文件已通过分享功能发送
- **THEN** 系统 SHALL 将文件存储在系统临时目录，由操作系统负责清理

### Requirement: 大数据量导出
系统 SHALL 支持导出大量交易记录（10 万条以上）且不导致内存溢出。数据查询 SHALL 采用分批方式（每批不超过 500 条）。文件写入 SHALL 采用流式方式以控制内存占用。

#### Scenario: 分批查询
- **WHEN** 数据库中有 10000 条交易记录需导出
- **THEN** 系统 SHALL 分 20 批（每批 500 条）查询并写入文件

#### Scenario: 空数据导出
- **WHEN** 筛选条件匹配到 0 条记录
- **THEN** 系统 SHALL 提示"没有符合条件的数据"并 SHALL NOT 生成文件

### Requirement: CSV 列定义
CSV 导出文件 SHALL 包含以下列：日期（yyyy-MM-dd）、时间（HH:mm）、类型（支出/收入）、分类名称、金额（正数，不带符号）、账户名称、备注。首行 SHALL 为中文列标题。

#### Scenario: CSV 列格式
- **WHEN** 导出一条交易：2026-02-17 餐饮 支出 ¥35.50 钱包 备注"午餐"
- **THEN** CSV 行 SHALL 为：`2026-02-17,12:00,支出,餐饮,35.50,钱包,午餐`
