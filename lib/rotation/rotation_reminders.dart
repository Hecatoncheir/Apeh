import 'dart:async';

import 'package:flutter/foundation.dart';

import 'rotation.dart';
import 'rotation_notifications.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_storage.dart';

class RotationReminders extends ChangeNotifier {
  RotationReminders(this._storage, this._notifications);

  final RotationStorage _storage;
  final RotationNotifications _notifications;
  RotationReminderSettings _settings = RotationReminderSettings.disabled;
  RotationSnapshot? _snapshot;
  String? _message;
  bool _busy = true;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  RotationReminderSettings get settings => _settings;
  String? get message => _message;
  bool get busy => _busy;

  Future<void> restore(RotationSnapshot? snapshot) async {
    _snapshot = snapshot;
    try {
      final saved = await _storage.readReminders();
      if (_disposed || saved == null) return;
      _settings = saved;
      await _sync();
    } on Exception {
      _message = 'Не удалось прочитать настройки напоминаний.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void updateSchedule(RotationSnapshot snapshot) {
    _snapshot = snapshot;
    if (_settings.enabled) unawaited(_sync());
  }

  Future<void> save(RotationReminderSettings value) async {
    if (_disposed || _busy) return;
    _busy = true;
    _notify();
    try {
      await _storage.saveReminders(value);
      if (_disposed) return;
      _settings = value;
      await _sync(requestPermission: value.enabled);
    } on Exception {
      _message = 'Не удалось сохранить настройки напоминаний.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _sync({bool requestPermission = false}) {
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        final plan = planMapReminders(_settings, _snapshot, DateTime.now());
        _message = await _notifications.sync(
          plan,
          enabled: _settings.enabled,
          requestPermission: requestPermission && _settings.enabled,
        );
      } catch (error) {
        debugPrint('Не удалось запланировать напоминания Apeh: $error');
        _message =
            'Не удалось настроить уведомления. Проверьте настройки системы.';
      }
      _notify();
    });
    return _pending;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _notifications.dispose();
    super.dispose();
  }
}
