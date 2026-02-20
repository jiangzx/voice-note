import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/di/network_providers.dart';
import 'features/settings/presentation/providers/theme_providers.dart';

class SuikoujiApp extends ConsumerStatefulWidget {
  const SuikoujiApp({super.key});

  @override
  ConsumerState<SuikoujiApp> createState() => _SuikoujiAppState();
}

class _SuikoujiAppState extends ConsumerState<SuikoujiApp> {
  @override
  void initState() {
    super.initState();
    ref.read(themeModeProvider.notifier).initialize();
    ref.read(themeColorProvider.notifier).initialize();
    ref.read(networkStatusServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: '快记账',
      theme: buildTheme(seedColor, Brightness.light),
      darkTheme: buildTheme(seedColor, Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
