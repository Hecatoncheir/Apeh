import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rotation.dart';
import 'rotation_repository.dart';
import 'rotation_reminder_plan.dart';

class RotationStorage {
  static const _snapshotKey = 'rotation.snapshot.v1';
  static const _apiKey = 'rotation.alsKey';
  static const _timeZoneKey = 'rotation.timeZone';
  static const _remindersKey = 'rotation.reminders.v1';
  final _secure = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<RotationSnapshot?> readSnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_snapshotKey);
    return value == null ? null : decodeRotationSnapshot(value);
  }

  Future<void> saveSnapshot(RotationSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      _snapshotKey,
      encodeRotationSnapshot(snapshot),
    )) {
      throw Exception('Не удалось сохранить расписание.');
    }
  }

  Future<String?> readKey() => _secure.read(key: _apiKey);

  Future<void> saveKey(String? value) => value == null
      ? _secure.delete(key: _apiKey)
      : _secure.write(key: _apiKey, value: value);

  Future<String?> readTimeZone() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_timeZoneKey);
  }

  Future<void> saveTimeZone(String id) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_timeZoneKey, id)) {
      throw Exception('Не удалось сохранить часовой пояс.');
    }
  }

  Future<RotationReminderSettings?> readReminders() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_remindersKey);
    if (value == null) return null;
    if (jsonDecode(value)
        case {
          'minutes': final int minutes,
          'playlists': final List<Object?> modes,
        }
        when minutes >= 0 && minutes <= RotationReminderSettings.maxMinutes) {
      return RotationReminderSettings(
        minutes,
        Playlist.values.where((mode) => modes.contains(mode.name)),
      );
    }
    throw const FormatException();
  }

  Future<void> saveReminders(RotationReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final value = jsonEncode({
      'minutes': settings.minutes,
      'playlists': [for (final mode in settings.playlists) mode.name],
    });
    if (!await preferences.setString(_remindersKey, value)) {
      throw Exception('Не удалось сохранить настройки напоминаний.');
    }
  }
}
