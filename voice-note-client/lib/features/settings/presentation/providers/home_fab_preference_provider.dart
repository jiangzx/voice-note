import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/network_providers.dart';

const _keyHideFabOnHomeAndStats = 'hide_fab_on_home_and_stats';
const _keyHomePillOffsetDx = 'home_pill_offset_dx';
const _keyHomePillOffsetDy = 'home_pill_offset_dy';

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

/// Persisted offset for the home draggable pill. Null = use default (bottom center).
class HomePillOffsetNotifier extends Notifier<Offset?> {
  @override
  Offset? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final dx = prefs.getDouble(_keyHomePillOffsetDx);
    final dy = prefs.getDouble(_keyHomePillOffsetDy);
    if (dx != null && dy != null) return Offset(dx, dy);
    return null;
  }

  void setOffset(Offset value) {
    state = value;
    ref.read(sharedPreferencesProvider)
      ..setDouble(_keyHomePillOffsetDx, value.dx)
      ..setDouble(_keyHomePillOffsetDy, value.dy);
  }
}

final homePillOffsetProvider =
    NotifierProvider<HomePillOffsetNotifier, Offset?>(
  HomePillOffsetNotifier.new,
);
