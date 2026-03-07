import 'package:flutter/material.dart';

class AppPreferencesState {
  final ThemeMode themeMode;
  final Locale locale;

  const AppPreferencesState({required this.themeMode, required this.locale});

  AppPreferencesState copyWith({ThemeMode? themeMode, Locale? locale}) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }
}

class AppPreferences {
  static final ValueNotifier<AppPreferencesState> notifier =
      ValueNotifier<AppPreferencesState>(
        const AppPreferencesState(
          themeMode: ThemeMode.system,
          locale: Locale('vi'),
        ),
      );

  static ThemeMode mapThemeMode(String value) {
    if (value == 'light') return ThemeMode.light;
    if (value == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  static Locale mapLocale(String code) {
    if (code == 'en') return const Locale('en');
    return const Locale('vi');
  }

  static void apply({required String themeMode, required String languageCode}) {
    notifier.value = notifier.value.copyWith(
      themeMode: mapThemeMode(themeMode),
      locale: mapLocale(languageCode),
    );
  }

  static String tr(String vi, String en) {
    return notifier.value.locale.languageCode == 'en' ? en : vi;
  }
}
