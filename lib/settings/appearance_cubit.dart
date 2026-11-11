import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'appearance_settings.dart';

typedef AppearanceState = ({AppearanceSettings settings, bool ready});

class AppearanceCubit extends Cubit<AppearanceState> {
  AppearanceCubit()
    : super((settings: const AppearanceSettings(), ready: false)) {
    unawaited(_restore());
  }

  Future<bool> _pending = Future.value(true);

  Future<void> _restore() async {
    var settings = state.settings;
    try {
      settings = await AppearanceSettings.load();
    } on Exception {
      // При сбое чтения доступны настройки по умолчанию.
    }
    if (!isClosed) emit((settings: settings, ready: true));
  }

  Future<bool> setLanguage(AppLanguage value) => _save(
    () => AppearanceSettings.saveLanguage(value),
    (settings) => settings.copyWith(language: value),
  );

  Future<bool> setTheme(ThemeMode value) => _save(
    () => AppearanceSettings.saveTheme(value),
    (settings) => settings.copyWith(theme: value),
  );

  Future<bool> setScale(int value) => _save(
    () => AppearanceSettings.saveScale(value),
    (settings) => settings.copyWith(scale: value),
  );

  Future<bool> _save(
    Future<bool> Function() persist,
    AppearanceSettings Function(AppearanceSettings) update,
  ) {
    _pending = _pending.then((_) async {
      try {
        if (!await persist()) return false;
        if (!isClosed) emit((settings: update(state.settings), ready: true));
        return true;
      } on Exception {
        return false;
      }
    });
    return _pending;
  }
}
