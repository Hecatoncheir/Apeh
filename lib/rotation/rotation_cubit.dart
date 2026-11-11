import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'demo_rotation.dart';
import 'rotation.dart';
import 'rotation_reminders.dart';
import 'rotation_repository.dart';
import 'rotation_storage.dart';
import 'rotation_time_zone.dart';

enum RotationPhase { initializing, idle, refreshing, savingKey }

typedef ScheduleState = ({
  RotationSnapshot? snapshot,
  bool fromCache,
  bool demo,
  String? message,
});

typedef ZoneState = ({RotationTimeZone value, bool changing, String? message});
typedef KeyState = ({bool present, String? message});

class RotationState {
  const RotationState({
    required this.now,
    required this.canLoad,
    this.phase = RotationPhase.initializing,
    this.schedule = (
      snapshot: null,
      fromCache: false,
      demo: false,
      message: null,
    ),
    this.zone = (value: RotationTimeZone.device, changing: true, message: null),
    this.key = (present: false, message: null),
  });

  final DateTime now;
  final bool canLoad;
  final RotationPhase phase;
  final ScheduleState schedule;
  final ZoneState zone;
  final KeyState key;

  bool get loading =>
      canLoad &&
      (phase == RotationPhase.initializing ||
          phase == RotationPhase.refreshing);
  bool get canRefresh => canLoad && phase == RotationPhase.idle;

  RotationState copyWith({
    DateTime? now,
    RotationPhase? phase,
    ScheduleState? schedule,
    ZoneState? zone,
    KeyState? key,
  }) => RotationState(
    now: now ?? this.now,
    canLoad: canLoad,
    phase: phase ?? this.phase,
    schedule: schedule ?? this.schedule,
    zone: zone ?? this.zone,
    key: key ?? this.key,
  );
}

class RotationCubit extends Cubit<RotationState> {
  RotationCubit(
    this._repository,
    this._storage, {
    required bool canLoad,
    this.reminders,
  }) : super(RotationState(now: DateTime.now(), canLoad: canLoad)) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_readTimeZone());
    if (canLoad) unawaited(_initialize());
  }

  static const _refreshInterval = Duration(minutes: 3);
  final RotationRepository _repository;
  final RotationStorage _storage;
  final RotationReminders? reminders;
  late final Timer _timer;
  String? _key;
  DateTime? _refreshAt;

  Future<void> _readTimeZone() async {
    try {
      final zone = RotationTimeZone.fromId(await _storage.readTimeZone());
      _showZone(zone);
    } on Exception {
      _showZone(
        state.zone.value,
        message: 'Не удалось прочитать сохранённый часовой пояс.',
      );
    }
  }

  Future<void> setTimeZone(RotationTimeZone zone) async {
    if (isClosed || state.zone.changing || zone.id == state.zone.value.id) {
      return;
    }
    emit(state.copyWith(zone: (value: zone, changing: true, message: null)));
    try {
      await _storage.saveTimeZone(zone.id);
      _showZone(zone);
    } on Exception {
      _showZone(
        zone,
        message: 'Часовой пояс действует до закрытия приложения.',
      );
    }
  }

  void _showZone(RotationTimeZone zone, {String? message}) {
    if (!isClosed) {
      emit(
        state.copyWith(zone: (value: zone, changing: false, message: message)),
      );
    }
  }

  Future<void> _initialize() async {
    final snapshot = await _readCache();
    if (isClosed) return;
    if (reminders case final controller?) {
      unawaited(controller.restore(snapshot));
    }
    final key = await _readKey();
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: RotationPhase.idle,
        schedule: (
          snapshot: snapshot,
          fromCache: snapshot != null,
          demo: false,
          message: null,
        ),
        key: key,
      ),
    );
    await refresh();
  }

  Future<RotationSnapshot?> _readCache() async {
    try {
      return await _storage.readSnapshot();
    } on Exception {
      return null;
    }
  }

  Future<KeyState> _readKey() async {
    try {
      _key = await _storage.readKey();
      return (present: _key != null, message: null);
    } on Exception {
      return (
        present: false,
        message: 'Не удалось прочитать сохранённый ключ API.',
      );
    }
  }

  Future<void> setKey(String? key) async {
    if (isClosed || !state.canRefresh) return;
    emit(
      state.copyWith(
        phase: RotationPhase.savingKey,
        key: (present: _key != null, message: null),
      ),
    );
    final result = await _saveKey(key);
    if (isClosed) return;
    emit(state.copyWith(phase: RotationPhase.idle, key: result));
    await refresh();
  }

  Future<KeyState> _saveKey(String? key) async {
    try {
      await _storage.saveKey(key);
      _key = key;
      return (present: _key != null, message: null);
    } on Exception {
      if (key == null) {
        return (
          present: _key != null,
          message: 'Не удалось удалить сохранённый ключ API.',
        );
      }
      _key = key;
      return (
        present: true,
        message: 'Ключ будет действовать до закрытия приложения.',
      );
    }
  }

  void showDemo() {
    if (state.canLoad) return;
    final now = DateTime.now();
    emit(
      state.copyWith(
        now: now,
        schedule: (
          snapshot: demoRotation(now),
          fromCache: false,
          demo: true,
          message: null,
        ),
      ),
    );
  }

  Future<void> refresh() async {
    if (isClosed || !state.canRefresh) return;
    emit(state.copyWith(phase: RotationPhase.refreshing, now: DateTime.now()));
    try {
      final (snapshot, notice) = await _load();
      if (isClosed) return;
      final now = DateTime.now();
      _refreshAt = _nextRefresh(snapshot, now);
      reminders?.updateSchedule(snapshot);
      emit(
        state.copyWith(
          now: now,
          schedule: (
            snapshot: snapshot,
            fromCache: false,
            demo: false,
            message: notice,
          ),
        ),
      );
      await _saveCache(snapshot);
    } on Exception catch (error) {
      _showFailure(error);
    } finally {
      if (!isClosed) emit(state.copyWith(phase: RotationPhase.idle));
    }
  }

  Future<void> _saveCache(RotationSnapshot snapshot) async {
    try {
      await _storage.saveSnapshot(snapshot);
    } on Exception {
      // Расписание доступно в текущем сеансе.
    }
  }

  void _showFailure(Exception error) {
    if (isClosed) return;
    final snapshot = state.schedule.snapshot;
    _refreshAt = DateTime.now().add(_refreshInterval);
    emit(
      state.copyWith(
        schedule: (
          snapshot: snapshot,
          fromCache: snapshot != null,
          demo: false,
          message: _errorMessage(error),
        ),
      ),
    );
  }

  Future<(RotationSnapshot, String?)> _load() async {
    final key = _key;
    if (key == null) {
      return (_requireUsable(await _repository.loadPublic()), null);
    }
    try {
      return (_requireUsable(await _repository.load(key)), null);
    } on Exception catch (error) {
      final snapshot = _requireUsable(await _repository.loadPublic());
      return (
        snapshot,
        '${_errorMessage(error)} Используется публичное расписание.',
      );
    }
  }

  RotationSnapshot _requireUsable(RotationSnapshot snapshot) {
    final now = DateTime.now();
    final hasAllModes = Playlist.values.every((mode) {
      final rotation = snapshot.playlists[mode];
      return rotation?.activeAt(now) != null ||
          rotation?.upcomingAt(now) != null;
    });
    if (!hasAllModes) throw const FormatException();
    return snapshot;
  }

  String _errorMessage(Exception error) => switch (error) {
    RotationException(:final message) => message,
    FormatException() => 'Не удалось прочитать расписание Apex Legends Status.',
    _ => 'Не удалось загрузить расписание. Проверьте подключение к сети.',
  };

  DateTime _nextRefresh(RotationSnapshot snapshot, DateTime now) {
    var refreshAt = now.add(_refreshInterval);
    for (final playlist in snapshot.playlists.values) {
      final boundary =
          playlist.activeAt(now)?.end ?? playlist.upcomingAt(now)?.start;
      if (boundary == null) continue;
      final candidate = boundary.add(const Duration(seconds: 2));
      if (candidate.isBefore(refreshAt)) refreshAt = candidate;
    }
    return refreshAt;
  }

  void _tick() {
    final now = DateTime.now();
    if (_refreshAt case final time?
        when state.canRefresh && !now.isBefore(time)) {
      unawaited(refresh());
    } else if (state.schedule.snapshot != null) {
      emit(state.copyWith(now: now));
    }
  }

  @override
  Future<void> close() {
    _timer.cancel();
    final closing = super.close();
    final controller = reminders;
    if (controller == null) return closing;
    return Future.wait([closing, controller.close()]);
  }
}
