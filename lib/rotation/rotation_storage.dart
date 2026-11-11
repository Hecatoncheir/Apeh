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
    final Object? decoded = jsonDecode(value);
    if (decoded
        case final Map<String, Object?> data &&
            {
              'minutes': final int minutes,
              'playlists': final List<Object?> modes,
            }
        when minutes >= 0 && minutes <= RotationReminderSettings.maxMinutes) {
      return RotationReminderSettings(
        minutes,
        _playlists(modes),
        favorites: _favorites(data['favorites']),
      );
    }
    throw const FormatException();
  }

  Iterable<Playlist> _playlists(List<Object?> names) =>
      Playlist.values.where((mode) => names.contains(mode.name));

  Iterable<FavoriteMap> _favorites(Object? value) sync* {
    if (value is! List<Object?>) return;
    for (final item in value) {
      if (item case {
        'map': final String name,
        'playlists': final List<Object?> modes,
      }) {
        final playlists = _playlists(modes);
        if (name.trim().isNotEmpty && playlists.isNotEmpty) {
          yield FavoriteMap(name, playlists);
        }
      }
    }
  }

  Future<void> saveReminders(RotationReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final value = jsonEncode({
      'minutes': settings.minutes,
      'playlists': [for (final mode in settings.playlists) mode.name],
      'favorites': [
        for (final favorite in settings.favorites)
          {
            'map': favorite.name,
            'playlists': [for (final mode in favorite.playlists) mode.name],
          },
      ],
    });
    if (!await preferences.setString(_remindersKey, value)) {
      throw Exception('Не удалось сохранить настройки напоминаний.');
    }
  }
}
