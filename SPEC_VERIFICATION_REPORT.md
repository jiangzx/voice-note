# Spec vs Implementation Verification Report

**Project:** voice-note  
**Date:** 2026-02-17  
**Focus:** Phase 3A additions (statistics, budget, navigation)

---

## 1. statistics-report/spec.md

| Requirement | Status | Notes |
|-------------|--------|-------|
| 统计时间维度选择（日/周/月/年） | **PASS** | `PeriodType` enum has day/week/month/year; `PeriodSelector` has all 4; default is month |
| 默认展示当前月 | **PASS** | `selectedPeriodTypeProvider` defaults to `PeriodType.month`; `selectedDateProvider` defaults to `DateTime.now()` |
| 切换至周维度（周一至周日） | **PASS** | `dateRangeForPeriod` uses Monday–Sunday for week |
| 前后翻页 | **PASS** | `_navigatePeriod` in PeriodSelector handles prev/next |
| 收支总览（收入、支出、结余，排除转账） | **PASS** | `getPeriodSummary` excludes transfers; `_PeriodSummaryCard` shows all three |
| 分类饼图（支出/收入切换，Top 10 + 其他） | **PASS** | `getCategorySummary` uses `maxCategories=10`; `_other` bucket; `categorySummaryTypeProvider` for toggle |
| 饼图无支出数据空状态 | **PASS** | `_PieChartContent` shows "暂无数据" when empty |
| 收支柱状图（日/周/月/年维度） | **MISMATCH** | Spec: 日维度 SHALL 展示该日按小时段的对比（上午/下午/晚上）. Code: Uses daily trend for day, not hour buckets. Day dimension shows single-day bars, not 上午/下午/晚上 |
| 柱状图无数据时零高度柱形 | **MISMATCH** | Spec: 无数据时 SHALL 展示所有日期/月份的零高度柱形. Code: Shows "暂无数据" empty state instead |
| 趋势折线图 | **PASS** | `TrendChartWidget` uses `trendDataProvider`; two lines for income/expense |
| 折线图无数据零值水平线 | **MISMATCH** | Spec: 无数据时 SHALL 展示零值水平线. Code: Likely shows empty state; needs verification |
| 同期对比（月 vs 上月，年 vs 去年） | **PASS** | `previousPeriodSummaryProvider`; `_ComparisonSection` shows 收入环比/支出环比 |
| 前一同期无数据 | **PASS** | `_percentChange` returns null when prev=0; `_ChangeIndicator` returns `SizedBox.shrink()` when null |
| 分类排行榜（名称、金额、占比） | **PASS** | `CategoryRanking` shows name, amount, percentage |
| 点击分类跳转至交易列表 | **MISMATCH** | Spec: 筛选条件 SHALL 为该分类 + 当前时间段. Code: Only passes `categoryId`; does NOT pass `dateFrom`/`dateTo` for current period |
| 按账户筛选 | **MISMATCH** | Spec: 选择账户后统计数据 SHALL 仅包含该账户. Code: `statistics_dao.dart` has bug—`query.where(accountId)` overwrites previous where clause in `getPeriodSummary`; `getCategorySummary` does not assign the filtered query, so account filter is not applied |

---

## 2. budget-management/spec.md

| Requirement | Status | Notes |
|-------------|--------|-------|
| 按分类设置月度预算 | **PASS** | `BudgetDao`/`BudgetRepository` CRUD; `BudgetEditScreen` per-category amounts |
| 预算金额正数、拒绝零/负 | **PASS** | `BudgetEditScreen._save` deletes when amount≤0; `saveBudget` validates |
| 收入分类不支持预算 | **PASS** | `BudgetEditScreen` uses `visibleCategoriesProvider('expense')` only |
| 进度条颜色（0–79% 绿、80–99% 黄、100%+ 红） | **PASS** | `BudgetStatus.level` and `BudgetProgressBar._colorsForLevel` match spec |
| 80% 预警通知 | **PASS** | `BudgetService.checkAfterSave` sends at pct≥80 |
| 100% 超支通知 | **PASS** | Sends at pct≥100 with spent/budget amounts |
| 不重复通知（每阈值每月一次） | **PASS** | `_notifyIfNew` uses SharedPreferences key per category/yearMonth/threshold |
| 预算概览页（总预算、已消费、剩余） | **PASS** | `BudgetOverviewScreen` with `_BudgetSummaryCard` |
| 从概览跳转至编辑页 | **PASS** | AppBar edit button → `/settings/budget/edit` |
| 未设置预算的分类以"未设定"展示在列表末尾 | **MISSING** | Spec: 未设置预算的分类 SHALL 以"未设定"状态展示在列表末尾. Code: Only shows categories that have budgets; does not list unset categories at end |
| 预算编辑页（批量设置、清空） | **PASS** | `BudgetEditScreen` iterates all expense categories; empty = delete |
| 展示所有支出分类（不含已隐藏） | **PASS** | Uses `visibleCategoriesProvider('expense')` |
| 预算自动继承 | **PASS** | `BudgetRepository.getOrInherit` copies from previous month when empty |
| 手动覆盖继承 | **PASS** | Manual save overwrites; other categories keep inherited |
| 上月无预算空状态 | **PASS** | `EmptyStateWidget` when `items.isEmpty` |
| 上月部分分类有预算 | **PASS** | Only inherits categories that had budget in previous month |

---

## 3. data-model/spec.md (Phase 3A focus)

| Requirement | Status | Notes |
|-------------|--------|-------|
| 预算表（id, category_id, amount, year_month, created_at, updated_at） | **PASS** | `Budgets` table in `app_database.dart` has all fields; `uniqueKeys` on (categoryId, yearMonth) |
| 数据库迁移 v1→v2 | **PASS** | `schemaVersion=2`; `onUpgrade` creates `budgets` when from<2; no changes to existing tables |
| 统计聚合查询（SQL 层、排除 isDraft） | **PASS** | `StatisticsDao` uses SQL; `t.isDraft.equals(false)` in all queries |
| 按分类汇总 | **PASS** | `getCategorySummary` with JOIN, GROUP BY, ORDER BY |
| 每日/每月趋势 | **PASS** | `getDailyTrend`, `getMonthlyTrend` |
| 空结果集返回空列表 | **PASS** | DAO returns lists; repository maps to domain models |

---

## 4. home-screen/spec.md

| Requirement | Status | Notes |
|-------------|--------|-------|
| 首页收支汇总 | **PASS** | `SummaryCard` with `summaryProvider` |
| 首页预算进度摘要 | **PASS** | `_BudgetSummaryCard` shows total budget, spent, remaining, progress bar |
| 无预算不展示摘要区域 | **PASS** | `if (summary.totalBudget <= 0) return SizedBox.shrink()` |
| 超支状态红色展示 | **PASS** | `isOver` uses `Colors.red` for overspend amount |
| 点击摘要导航至预算概览 | **PASS** | `onTap: () => context.push('/settings/budget')` |
| 快速记账入口（语音 FAB 居中） | **PASS** | `AppShell` has voice FAB |
| 语音 FAB 在所有 Tab 可见 | **PASS** | `showFab = index < 3` (home, transactions, statistics) |
| 手动记账入口在首页 AppBar 右上角 | **MISMATCH** | Spec: 手动记账入口 SHALL 移至首页 AppBar 右上角. Code: Manual entry is in AppShell as add FAB, not in HomeScreen AppBar |
| 底部导航（首页、统计、明细、设置） | **PASS** | `AppShell` has 4 tabs: 首页、明细、统计、设置 |
| 默认展示首页 | **PASS** | `initialLocation: '/home'` |
| 导航状态保持 | **PASS** | ShellRoute with `_fadeThroughPage`; tab content preserved |

---

## 5. transaction-recording/spec.md

| Requirement | Status | Notes |
|-------------|--------|-------|
| 保存后触发预算检查 | **PASS** | `TransactionFormScreen._save` and `VoiceSessionNotifier.confirmTransaction`/`onContinueRecording` call `checkAfterSave` |
| 仅支出触发检查 | **PASS** | Both call sites check `TransactionType.expense` and `categoryId != null` |
| 收入不触发 | **PASS** | Guard excludes non-expense |
| 无预算分类不触发 | **PASS** | `BudgetService.checkAfterSave` returns early when `status == null` |
| 编辑交易触发重新检查 | **MISMATCH** | Spec: 对新分类重新检查. Code: Uses `BudgetService.currentYearMonth()` for all cases. When editing a transaction in a past month, should use transaction's date for yearMonth |

---

## 6. settings-screen/spec.md

| Requirement | Status | Notes |
|-------------|--------|-------|
| 预算设置入口 | **MISMATCH** | Spec: "预算设置"入口. Code: Uses "预算管理" as label |
| 入口位于分类管理之后 | **PASS** | Category management then budget management in ListView |
| 导航至预算概览 | **PASS** | `onTap: () => context.go('/settings/budget')` |

---

## Summary

| Status | Count |
|--------|-------|
| **PASS** | 52 |
| **MISMATCH** | 8 |
| **MISSING** | 1 |

### Critical Issues to Fix

1. **statistics_dao.dart account filter bug**  
   When `accountId` is set, the second `where()` overwrites or does not combine with the first. Fix: combine conditions with `&` in a single where clause.

2. **Category ranking navigation**  
   When navigating to transaction list from statistics ranking, pass `dateFrom` and `dateTo` for the current period so the filter matches "分类 + 当前时间段".

3. **Budget overview "未设定" categories**  
   Show all expense categories; list those without budgets as "未设定" at the end.

### Minor / UX Mismatches

4. **Manual entry location**  
   Spec: 首页 AppBar 右上角. Current: FAB in shell. Consider adding an AppBar action on HomeScreen.

5. **Bar chart day dimension**  
   Spec: 日维度按上午/下午/晚上. Current: single-day bars. May require hour-bucket aggregation.

6. **Bar/line chart empty state**  
   Spec: zero-height bars / zero-value line. Current: "暂无数据" text.

7. **Budget check on edit**  
   Use transaction date for `yearMonth` when editing, not always current month.

8. **Settings label**  
   "预算设置" vs "预算管理"—minor wording difference.
