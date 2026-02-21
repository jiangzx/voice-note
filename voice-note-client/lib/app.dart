import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/di/network_providers.dart';
import 'features/settings/presentation/providers/security_settings_provider.dart';
import 'features/settings/presentation/providers/theme_providers.dart';

class SuikoujiApp extends ConsumerStatefulWidget {
  const SuikoujiApp({super.key});

  @override
  ConsumerState<SuikoujiApp> createState() => _SuikoujiAppState();
}

class _SuikoujiAppState extends ConsumerState<SuikoujiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(themeModeProvider.notifier).initialize();
    ref.read(themeColorProvider.notifier).initialize();
    // Defer so provider state update happens after build; avoids "modify provider while building" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(securitySettingsProvider.notifier).initSettings();
    });
    ref.read(networkStatusServiceProvider).init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(securitySettingsProvider.notifier).clearUnlockedThisSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: '快记账',
      theme: buildLightTheme(),
      darkTheme: buildTheme(seedColor, Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
