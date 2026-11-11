import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  automatic(null),
  russian(Locale('ru')),
  english(Locale('en'));

  const AppLanguage(this.locale);

  final Locale? locale;
}

class AppearanceSettings {
  const AppearanceSettings({
    this.language = AppLanguage.russian,
    this.theme = ThemeMode.system,
    this.scale = 100,
  });

  static const scales = [80, 90, 100, 110, 125];
  static const _language = 'appearance.language';
  static const _theme = 'appearance.theme';
  static const _scale = 'appearance.scale';

  final AppLanguage language;
  final ThemeMode theme;
  final int scale;

  static Future<AppearanceSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.get(_language);
    final theme = prefs.get(_theme);
    final scale = prefs.get(_scale);
    return AppearanceSettings(
      language:
          AppLanguage.values
              .where((item) => item.name == language)
              .firstOrNull ??
          AppLanguage.russian,
      theme:
          ThemeMode.values.where((item) => item.name == theme).firstOrNull ??
          ThemeMode.system,
      scale: scale is int && scales.contains(scale) ? scale : 100,
    );
  }

  static Future<bool> saveLanguage(AppLanguage value) async =>
      (await SharedPreferences.getInstance()).setString(_language, value.name);

  static Future<bool> saveTheme(ThemeMode value) async =>
      (await SharedPreferences.getInstance()).setString(_theme, value.name);

  static Future<bool> saveScale(int value) async =>
      (await SharedPreferences.getInstance()).setInt(_scale, value);

  AppearanceSettings copyWith({
    AppLanguage? language,
    ThemeMode? theme,
    int? scale,
  }) => AppearanceSettings(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    scale: scale ?? this.scale,
  );
}

class ApehScale extends StatelessWidget {
  const ApehScale({super.key, required this.percent, required this.child});

  final int percent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = percent / 100;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest / factor;
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                devicePixelRatio: media.devicePixelRatio * factor,
                padding: media.padding / factor,
                viewPadding: media.viewPadding / factor,
                viewInsets: media.viewInsets / factor,
                systemGestureInsets: media.systemGestureInsets / factor,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
