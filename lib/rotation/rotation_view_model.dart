import 'dart:async';

import 'package:flutter/foundation.dart';

import 'demo_rotation.dart';
import 'rotation.dart';
import 'rotation_repository.dart';
import 'rotation_reminders.dart';
import 'rotation_storage.dart';
import 'rotation_time_zone.dart';

class RotationViewModel extends ChangeNotifier {
  RotationViewModel(
    this._repository,
    this._storage, {
    required this.canLoad,
    this.reminders,
  }) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    unawaited(_readTimeZone());
    if (canLoad) unawaited(_initialize());
  }

  final RotationRepository _repository;
  final RotationStorage _storage;
  final bool canLoad;
  final RotationReminders? reminders;
  late final Timer _timer;
  String? _key;
  bool _disposed = false;
  bool _initializing = true;
  bool _loading = false;
  bool _savingKey = false;
  bool _demo = false;
  bool _fromCache = false;
  DateTime _now = DateTime.now();
  DateTime? _refreshAt;
  RotationSnapshot? _snapshot;
  String? _message;
  String? _storageMessage;
  RotationTimeZone _timeZone = RotationTimeZone.device;
  bool _changingTimeZone = true;
  String? _timeZoneMessage;

  DateTime get now => _now;
  bool get loading => canLoad && (_initializing || _loading);
  bool get canChangeKey => canLoad && !loading && !_savingKey;
  bool get canRefresh => canChangeKey;
  bool get hasKey => _key != null;
  bool get demo => _demo;
  bool get fromCache => _fromCache;
  RotationSnapshot? get snapshot => _snapshot;
  String? get message => _message;
  String? get storageMessage => _storageMessage;
  RotationTimeZone get timeZone => _timeZone;
  bool get canChangeTimeZone => !_changingTimeZone;
  String? get timeZoneMessage => _timeZoneMessage;

  Future<void> _readTimeZone() async {
    try {
      _timeZone = RotationTimeZone.fromId(await _storage.readTimeZone());
    } on Exception {
      _timeZoneMessage = 'Не удалось прочитать сохранённый часовой пояс.';
    } finally {
      _changingTimeZone = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setTimeZone(RotationTimeZone value) async {
    if (_disposed || !canChangeTimeZone || value.id == _timeZone.id) return;
    _changingTimeZone = true;
    _timeZone = value;
    _timeZoneMessage = null;
    notifyListeners();
    try {
      await _storage.saveTimeZone(value.id);
    } on Exception {
      _timeZoneMessage = 'Часовой пояс действует до закрытия приложения.';
    } finally {
      _changingTimeZone = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _initialize() async {
    try {
      _snapshot = await _storage.readSnapshot();
      _fromCache = _snapshot != null;
    } on Exception {
      // Повреждённый кеш не мешает загрузить свежее расписание.
    }
    if (reminders case final controller? when !_disposed) {
      unawaited(controller.restore(_snapshot));
    }
    try {
      _key = await _storage.readKey();
    } on Exception {
      _storageMessage = 'Не удалось прочитать сохранённый ключ API.';
    }
    if (_disposed) return;
    _initializing = false;
    await refresh();
  }

  Future<void> setKey(String? key) async {
    if (!canChangeKey || _disposed) return;
    _savingKey = true;
    _storageMessage = null;
    notifyListeners();
    try {
      await _storage.saveKey(key);
      _key = key;
    } on Exception {
      if (key != null) {
        _key = key;
        _storageMessage = 'Ключ будет действовать до закрытия приложения.';
      } else {
        _storageMessage = 'Не удалось удалить сохранённый ключ API.';
      }
    } finally {
      _savingKey = false;
    }
    if (!_disposed) await refresh();
  }

  void showDemo() {
    if (canLoad) return;
    _demo = true;
    _now = DateTime.now();
    _snapshot = demoRotation(_now);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!canRefresh || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final (snapshot, notice) = await _load();
      if (_disposed) return;
      _snapshot = snapshot;
      _message = notice;
      _fromCache = false;
      _now = DateTime.now();
      _refreshAt = _nextRefresh(snapshot);
      reminders?.updateSchedule(snapshot);
      try {
        await _storage.saveSnapshot(snapshot);
      } on Exception {
        // Свежее расписание остаётся доступным в текущем сеансе.
      }
    } on Exception catch (error) {
      if (_disposed) return;
      _message = _errorMessage(error);
      _fromCache = _snapshot != null;
      _refreshAt = DateTime.now().add(const Duration(minutes: 3));
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<(RotationSnapshot, String?)> _load() async {
    String? notice;
    if (_key case final key?) {
      try {
        return (_requireUsable(await _repository.load(key)), null);
      } on Exception catch (error) {
        notice = '${_errorMessage(error)} Используется публичное расписание.';
      }
    }
    final public = _requireUsable(await _repository.loadPublic());
    return (public, notice);
  }

  RotationSnapshot _requireUsable(RotationSnapshot snapshot) {
    final now = DateTime.now();
    if (Playlist.values.every((mode) {
      final rotation = snapshot.playlists[mode];
      return rotation?.activeAt(now) != null ||
          rotation?.upcomingAt(now) != null;
    })) {
      return snapshot;
    }
    throw const FormatException();
  }

  String _errorMessage(Exception error) => switch (error) {
    RotationException(:final message) => message,
    FormatException() => 'Не удалось прочитать расписание Apex Legends Status.',
    _ => 'Не удалось загрузить расписание. Проверьте подключение к сети.',
  };

  DateTime _nextRefresh(RotationSnapshot snapshot) {
    var refreshAt = _now.add(const Duration(minutes: 3));
    for (final playlist in snapshot.playlists.values) {
      final boundary =
          playlist.activeAt(_now)?.end ?? playlist.upcomingAt(_now)?.start;
      if (boundary == null) continue;
      final candidate = boundary.add(const Duration(seconds: 2));
      if (candidate.isBefore(refreshAt)) refreshAt = candidate;
    }
    return refreshAt;
  }

  void tick() {
    _now = DateTime.now();
    if (_refreshAt case final time? when !_now.isBefore(time) && canRefresh) {
      unawaited(refresh());
    } else if (_snapshot != null) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    reminders?.dispose();
    super.dispose();
  }
}
