import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage/secure_storage.dart';

const _themeStorageKey = 'app_theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.dark;
  }

  Future<void> _loadTheme() async {
    final saved = await SecureStorage.get(_themeStorageKey);
    if (saved == 'light') {
      state = ThemeMode.light;
    } else if (saved == 'dark') {
      state = ThemeMode.dark;
    } else if (saved == 'system') {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.system) val = 'system';
    await SecureStorage.set(_themeStorageKey, val);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
