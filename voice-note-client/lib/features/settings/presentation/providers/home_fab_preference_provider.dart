import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/network_providers.dart';

const _keyHideFabOnHomeAndStats = 'hide_fab_on_home_and_stats';

/// Manages "hide FAB on home and statistics" preference with SharedPreferences.
class HideFabOnHomeAndStatsNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(sharedPreferencesProvider).getBool(_keyHideFabOnHomeAndStats) ?? false;
  }

  void setHideFabOnHomeAndStats(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_keyHideFabOnHomeAndStats, value);
  }
}

final hideFabOnHomeAndStatsProvider =
    NotifierProvider<HideFabOnHomeAndStatsNotifier, bool>(
  HideFabOnHomeAndStatsNotifier.new,
);
