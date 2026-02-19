## Context

Phase 1-2 已完成手动记账和语音记账功能。当前导航结构为 3 Tab（首页/明细/设置）+ 2 个 FAB（语音记账/手动记账）。数据层使用 drift (SQLite) 本地存储，schema version 1，包含 accounts、categories、transactions 三张表。

本次变更为纯客户端实现，Server 零变更。统计聚合查询通过 drift SQL 在本地完成。

## Goals / Non-Goals

**Goals:**
- 提供按日/周/月/年维度的收支统计（饼图、柱状图、折线图、同期对比）
- 提供按分类设置月度预算的能力，支持实时进度追踪和超支提醒
- 统计页作为底部 Tab，预算进度在首页摘要展示
- 数据库平滑迁移到 schema version 2

**Non-Goals:**
- 不实现数据导出（P4 范畴）
- 不实现 AI 消费洞察（v2.0 范畴）
- 不实现云端统计（纯本地计算）
- 不实现年度预算或自定义周期预算（MVP 仅月度）
- 不实现推送通知（Phase 5 需用户体系后集成极光推送；本次使用 flutter_local_notifications 本地通知）

## Decisions

### D1: 图表库选择 — fl_chart

| 方案 | 优点 | 缺点 |
|------|------|------|
| **fl_chart** ✅ | 纯 Dart 实现、高度可定制、动画流畅、社区活跃（6k+ stars） | 学习曲线稍陡 |
| syncfusion_flutter_charts | 功能全面、企业级 | 免费版有限制、包体较大 |
| graphic | 声明式 API | 成熟度不足、文档少 |

选择 fl_chart：轻量、纯 Dart、与 Material 3 主题集成好。

### D2: 导航结构调整 — 4 Tab + 居中语音 FAB

当前 3 Tab + 2 FAB 结构在新增统计 Tab 后，调整为：

```
 [首页]  [统计]  [🎙️ FAB]  [明细]  [设置]
```

- 底部 Tab 从 3 个变为 4 个：首页、统计、明细、设置
- 语音 FAB 移至中央悬浮位置（不占 Tab 位）
- 手动记账 FAB 合并到首页右上角 + 明细页右上角

**替代方案考虑：** 5 Tab（语音占一个 Tab 位）→ 否决，语音记账是全屏模态页面，不适合作为 Tab。

### D3: 数据库迁移 — drift schema v1 → v2

新增 `budgets` 表：

```sql
CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES categories(id),
  amount REAL NOT NULL,
  year_month TEXT NOT NULL,     -- "2026-02" 格式，便于查询
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

迁移策略：在 `MigrationStrategy` 的 `onUpgrade` 中处理 v1 → v2，仅新增表不影响现有数据。

### D4: 统计查询策略 — drift SQL 聚合

统计数据通过 drift 的自定义 SQL 查询实现，而非内存聚合：

```sql
-- 分类汇总（饼图数据）
SELECT c.name, c.color, c.icon, SUM(t.amount) as total
FROM transactions t JOIN categories c ON t.category_id = c.id
WHERE t.type = 'expense' AND t.date BETWEEN ? AND ?
GROUP BY t.category_id ORDER BY total DESC;

-- 每日趋势（折线图数据）
SELECT DATE(t.date) as day, t.type, SUM(t.amount) as total
FROM transactions t
WHERE t.date BETWEEN ? AND ?
GROUP BY day, t.type ORDER BY day;
```

**替代方案考虑：** 内存聚合（读取全量交易后在 Dart 中计算）→ 否决，数据量大时性能差。SQL 聚合在 SQLite 层高效完成。

### D5: 预算检查时机 — 交易保存后异步检查

每次交易保存后（手动 + 语音），异步调用 `BudgetService.checkBudget(categoryId)`:
1. 查询该分类本月预算和已消费总额
2. 若达 80% 或 100% → 通过 `flutter_local_notifications` 发送本地通知
3. 检查为异步非阻塞，不影响保存流程

### D6: 统计页时间范围选择器

使用 SegmentedButton 选择维度（日/周/月/年），加 左右箭头 切换时间段：

```
  [←]  2026年2月  [→]    [日] [周] [月✓] [年]
```

每次切换重新查询，结果通过 Riverpod FutureProvider 缓存。

## Directory Structure

```
voice-note-client/lib/features/
├── statistics/
│   ├── data/
│   │   ├── statistics_dao.dart          # drift DAO: 聚合查询
│   │   └── statistics_repository.dart   # Repository 封装
│   ├── domain/
│   │   └── models/
│   │       ├── category_summary.dart    # 分类汇总数据
│   │       ├── period_summary.dart      # 时间段汇总
│   │       └── trend_point.dart         # 趋势数据点
│   └── presentation/
│       ├── screens/
│       │   └── statistics_screen.dart   # 统计主页
│       ├── widgets/
│       │   ├── pie_chart_widget.dart    # 饼图
│       │   ├── bar_chart_widget.dart    # 柱状图
│       │   ├── trend_chart_widget.dart  # 折线图
│       │   ├── category_ranking.dart    # 分类排行
│       │   └── period_selector.dart     # 时间选择器
│       └── providers/
│           └── statistics_providers.dart
├── budget/
│   ├── data/
│   │   ├── budget_dao.dart              # drift DAO: CRUD
│   │   └── budget_repository.dart
│   ├── domain/
│   │   ├── budget_service.dart          # 预算检查逻辑
│   │   └── models/
│   │       └── budget_status.dart       # 预算状态（正常/预警/超支）
│   └── presentation/
│       ├── screens/
│       │   ├── budget_overview_screen.dart
│       │   └── budget_edit_screen.dart
│       ├── widgets/
│       │   └── budget_progress_bar.dart
│       └── providers/
│           └── budget_providers.dart
```

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| [导航调整] 4 Tab 改动影响现有测试 | app_shell_test.dart 需全面更新 |
| [数据库迁移] schema v1→v2 数据丢失 | onUpgrade 仅 CREATE TABLE，不 ALTER 现有表 |
| [性能] 大数据量聚合查询慢 | SQL 聚合 + 索引优化（date + type 联合索引） |
| [图表渲染] 数据量过大导致 fl_chart 卡顿 | 限制图表数据点（日最多 31，月最多 12），必要时取 Top 10 分类 |
| [本地通知权限] 用户拒绝通知权限 | 预算超支仍在 UI 内展示（进度条变红），通知仅为增强 |
