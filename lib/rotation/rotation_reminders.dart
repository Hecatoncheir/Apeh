import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'rotation.dart';
import 'rotation_notifications.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_storage.dart';

typedef ReminderState = ({
  RotationReminderSettings settings,
  bool busy,
  String? message,
});

class RotationReminders extends Cubit<ReminderState> {
  RotationReminders(this._storage, this._notifications)
    : super((
        settings: RotationReminderSettings.disabled,
        busy: true,
        message: null,
      ));

  final RotationStorage _storage;
  final RotationNotifications _notifications;
  RotationSnapshot? _snapshot;
  bool _english = false;
  Future<void> _pending = Future.value();

  Future<void> restore(RotationSnapshot? snapshot) async {
    _snapshot = snapshot;
    try {
      final saved = await _storage.readReminders();
      if (isClosed || saved == null) return;
      _setSettings(saved);
      await _sync();
    } on Exception {
      _setMessage('Не удалось прочитать настройки напоминаний.');
    } finally {
      _setBusy(false);
    }
  }

  void updateSchedule(RotationSnapshot snapshot) {
    _snapshot = snapshot;
    if (state.settings.enabled) unawaited(_sync());
  }

  void setEnglish(bool value) {
    if (_english == value) return;
    _english = value;
    if (state.settings.enabled) unawaited(_sync());
  }

  Future<void> save(RotationReminderSettings value) async {
    if (isClosed || state.busy) return;
    _setBusy(true);
    try {
      await _storage.saveReminders(value);
      if (isClosed) return;
      _setSettings(value);
      await _sync(requestPermission: value.enabled);
    } on Exception {
      _setMessage('Не удалось сохранить настройки напоминаний.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _sync({bool requestPermission = false}) {
    _pending = _pending.then((_) async {
      if (isClosed) return;
      final settings = state.settings;
      try {
        final plan = planMapReminders(
          settings,
          _snapshot,
          DateTime.now(),
          english: _english,
        );
        final message = await _notifications.sync(
          plan,
          enabled: settings.enabled,
          requestPermission: requestPermission && settings.enabled,
        );
        _setMessage(message);
      } catch (error) {
        debugPrint('Не удалось запланировать напоминания Apeh: $error');
        _setMessage(
          'Не удалось настроить уведомления. Проверьте настройки системы.',
        );
      }
    });
    return _pending;
  }

  void _setSettings(RotationReminderSettings settings) {
    emit((settings: settings, busy: state.busy, message: state.message));
  }

  void _setBusy(bool busy) {
    if (!isClosed) {
      emit((settings: state.settings, busy: busy, message: state.message));
    }
  }

  void _setMessage(String? message) {
    if (!isClosed) {
      emit((settings: state.settings, busy: state.busy, message: message));
    }
  }

  @override
  Future<void> close() {
    _notifications.dispose();
    return super.close();
  }
}
