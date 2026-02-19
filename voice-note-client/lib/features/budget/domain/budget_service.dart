import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/budget_repository.dart';

/// Handles budget threshold checks and notifications after transaction saves.
class BudgetService {
  BudgetService(this._repo, this._prefs);

  final BudgetRepository _repo;
  final SharedPreferences _prefs;

  /// Check budget for a category after a transaction save.
  /// Sends local notification if 80% or 100% threshold is reached for the
  /// first time this month.
  Future<void> checkAfterSave({
    required String categoryId,
    required String yearMonth,
  }) async {
    final status = await _repo.checkBudget(categoryId, yearMonth);
    if (status == null) return;

    final pct = status.percentage;
    if (pct >= 100) {
      await _notifyIfNew(
        key: _alertKey(categoryId, yearMonth, 100),
        title: '预算超支提醒',
        body:
            '${status.categoryName.isNotEmpty ? status.categoryName : "该分类"}预算已超支，'
            '本月已消费 ¥${status.spentAmount.toStringAsFixed(0)} / '
            '预算 ¥${status.budgetAmount.toStringAsFixed(0)}',
      );
    } else if (pct >= 80) {
      await _notifyIfNew(
        key: _alertKey(categoryId, yearMonth, 80),
        title: '预算预警',
        body:
            '${status.categoryName.isNotEmpty ? status.categoryName : "该分类"}'
            '预算已使用 ${pct.toStringAsFixed(0)}%，请注意控制消费',
      );
    }
  }

  /// Get the current year-month string (e.g. "2026-02").
  static String currentYearMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _notifyIfNew({
    required String key,
    required String title,
    required String body,
  }) async {
    if (_prefs.getBool(key) == true) return; // Already notified
    await NotificationService.instance.show(
      id: key.hashCode,
      title: title,
      body: body,
    );
    await _prefs.setBool(key, true);
  }

  String _alertKey(String categoryId, String yearMonth, int threshold) =>
      'budget_alert_${categoryId}_${yearMonth}_$threshold';
}
