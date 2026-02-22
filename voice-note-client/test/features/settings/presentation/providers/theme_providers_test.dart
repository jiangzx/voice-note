import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/settings/presentation/providers/theme_providers.dart';

void main() {
  group('ThemeModeNotifier', () {
    test('defaults to system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('initialize reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).initialize();
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setMode persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('ThemeColorNotifier', () {
    test('defaults to brand (亮蓝)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeColorProvider), AppThemeColors.brand);
    });

    test('initialize reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'theme_color': Colors.indigo.toARGB32(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeColorProvider.notifier).initialize();
      expect(
        container.read(themeColorProvider),
        Color(Colors.indigo.toARGB32()),
      );
    });

    test('setColor persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeColorProvider.notifier).setColor(Colors.orange);
      expect(container.read(themeColorProvider), Colors.orange);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_color'), Colors.orange.toARGB32());
    });
  });
}
