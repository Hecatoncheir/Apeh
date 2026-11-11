import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'rotation_reminder_plan.dart';

abstract interface class RotationNotifications {
  Future<String?> sync(
    List<MapReminder> plan, {
    required bool enabled,
    required bool requestPermission,
  });

  void dispose();
}

class LocalRotationNotifications implements RotationNotifications {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.fuchsia;

  static const _appleSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  static const _settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_map_notification'),
    iOS: _appleSettings,
    macOS: _appleSettings,
    linux: LinuxInitializationSettings(defaultActionName: 'Открыть Apeh'),
    windows: WindowsInitializationSettings(
      appName: 'Apeh',
      appUserModelId: 'Apeh.MapRotation',
      guid: '29f27dc7-b5c7-4f36-9e84-c1678bb99d8d',
    ),
  );
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('map_rotation', 'Смена карт'),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  final _timers = <int, Timer>{};
  final _applied = <int, MapReminder>{};
  bool _initialized = false;
  bool? _exact;
  bool _disposed = false;

  bool get _linux => defaultTargetPlatform == TargetPlatform.linux;

  @override
  Future<String?> sync(
    List<MapReminder> plan, {
    required bool enabled,
    required bool requestPermission,
  }) async {
    if (_disposed) return null;
    if (!_initialized) {
      _initialized = await _plugin.initialize(settings: _settings) == true;
      if (!_initialized) throw StateError('Уведомления недоступны.');
    }
    final allowed = !enabled || await _permission(requestPermission);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (enabled &&
        allowed &&
        requestPermission &&
        await android?.canScheduleExactNotifications() == false) {
      await android?.requestExactAlarmsPermission();
    }
    final exact = await android?.canScheduleExactNotifications() ?? true;
    if (_disposed) return null;
    final desired = allowed ? plan : const <MapReminder>[];
    if (_linux) {
      _syncTimers(desired);
    } else {
      await _syncScheduled(desired, exact);
    }
    if (!allowed) return 'Разрешите уведомления Apeh в настройках системы.';
    if (enabled && !exact) {
      return 'Android может задерживать напоминания без разрешения на точные сигналы.';
    }
    return null;
  }

  Future<bool> _permission(bool request) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (request) await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      if (request) await ios.requestPermissions(alert: true, sound: true);
      final options = await ios.checkPermissions();
      return options != null &&
          (options.isEnabled || options.isProvisionalEnabled);
    }
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (mac != null) {
      if (request) await mac.requestPermissions(alert: true, sound: true);
      final options = await mac.checkPermissions();
      return options != null &&
          (options.isEnabled || options.isProvisionalEnabled);
    }
    return true;
  }

  Future<void> _syncScheduled(List<MapReminder> plan, bool exact) async {
    final desired = {for (final reminder in plan) reminder.id: reminder};
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending.where((item) => isMapReminderId(item.id))) {
      final reminder = desired[request.id];
      if (reminder != null &&
          _applied[request.id] == reminder &&
          _exact == exact) {
        desired.remove(request.id);
      } else {
        await _plugin.cancel(id: request.id);
        _applied.remove(request.id);
      }
    }
    for (final reminder in desired.values) {
      if (_disposed ||
          !reminder.fireAt.isAfter(
            DateTime.now().add(const Duration(seconds: 1)),
          )) {
        continue;
      }
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _applied[reminder.id] = reminder;
    }
    _applied.removeWhere((id, _) => !plan.any((reminder) => reminder.id == id));
    _exact = exact;
  }

  void _syncTimers(List<MapReminder> plan) {
    final desired = {for (final reminder in plan) reminder.id: reminder};
    for (final id in _timers.keys.toList()) {
      if (desired[id] == _applied[id]) {
        desired.remove(id);
      } else {
        _timers.remove(id)?.cancel();
        _applied.remove(id);
      }
    }
    for (final reminder in desired.values) {
      final delay = reminder.fireAt.difference(DateTime.now());
      if (delay <= Duration.zero) continue;
      _applied[reminder.id] = reminder;
      _timers[reminder.id] = Timer(delay, () => unawaited(_show(reminder)));
    }
  }

  Future<void> _show(MapReminder reminder) async {
    _timers.remove(reminder.id);
    _applied.remove(reminder.id);
    if (_disposed ||
        DateTime.now().difference(reminder.fireAt) >
            const Duration(seconds: 10)) {
      return;
    }
    try {
      await _plugin.show(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
      );
    } on Exception catch (error) {
      debugPrint('Не удалось показать напоминание Apeh: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
