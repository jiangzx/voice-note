import 'package:riverpod/legacy.dart' show StateProvider;

/// Provider for managing FAB visibility state in transaction list screen.
/// 
/// When true, FABs are visible; when false, they are hidden.
/// Default value is true (visible).
final fabVisibilityProvider = StateProvider<bool>((ref) => true);

/// Provider for managing exit FAB visibility state in voice recording screen.
/// 
/// When true, exit FAB is visible; when false, it is hidden.
/// Default value is true (visible).
final voiceExitFabVisibilityProvider = StateProvider<bool>((ref) => true);
