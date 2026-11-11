import 'rotation.dart';

class RotationReminderSettings {
  RotationReminderSettings(this.minutes, Iterable<Playlist> playlists)
    : playlists = Set.unmodifiable(playlists);

  static const maxMinutes = 1440;
  static final disabled = RotationReminderSettings(5, const []);

  final int minutes;
  final Set<Playlist> playlists;

  bool get enabled => playlists.isNotEmpty;
}

typedef MapReminder = ({
  int id,
  DateTime fireAt,
  DateTime changeAt,
  String title,
  String body,
});

const _firstId = 0x10000000;
const _secondsMask = 0x0fffffff;

bool isMapReminderId(int id) =>
    id >= _firstId && id <= _firstId + (_secondsMask << 2) + 3;

List<MapReminder> planMapReminders(
  RotationReminderSettings settings,
  RotationSnapshot? snapshot,
  DateTime now, {
  bool english = false,
}) {
  final reminders = <int, MapReminder>{};
  for (final mode in settings.playlists) {
    final rotation = snapshot?.playlists[mode];
    if (rotation == null) continue;
    for (final reminder in _forMode(
      mode,
      rotation,
      settings.minutes,
      now,
      english,
    )) {
      reminders[reminder.id] = reminder;
    }
  }
  final ordered = reminders.values.toList()..sort(_byTime);
  return ordered.take(48).toList(growable: false);
}

Iterable<MapReminder> _forMode(
  Playlist mode,
  PlaylistRotation rotation,
  int minutes,
  DateTime now,
  bool english,
) sync* {
  final lead = Duration(minutes: minutes);
  final label = english && mode == Playlist.battleRoyale
      ? 'Regular BR'
      : mode.label;
  for (final slot in rotation.slots) {
    final changeAt = slot.start.toUtc();
    final fireAt = changeAt.subtract(lead);
    if (!fireAt.isAfter(now) || _repeatsCurrent(rotation, slot)) continue;
    final seconds = changeAt.millisecondsSinceEpoch ~/ 1000;
    final map = [slot.name, slot.variant].nonNulls.join(' · ');
    yield (
      id: _firstId + ((seconds & _secondsMask) << 2) + mode.index,
      fireAt: fireAt,
      changeAt: changeAt,
      title: 'Apeh · $label',
      body: _body(map, minutes, english),
    );
  }
}

bool _repeatsCurrent(PlaylistRotation rotation, MapSlot slot) {
  final previous = rotation.activeAt(
    slot.start.subtract(const Duration(milliseconds: 1)),
  );
  return previous?.name == slot.name && previous?.variant == slot.variant;
}

int _byTime(MapReminder first, MapReminder second) {
  final time = first.fireAt.compareTo(second.fireAt);
  return time == 0 ? first.id.compareTo(second.id) : time;
}

String _body(String map, int minutes, bool english) =>
    switch ((english, minutes)) {
      (true, 0) => 'The map is changing to $map.',
      (true, _) => 'Next map: $map in $minutes min.',
      (false, 0) => 'Карта меняется на $map.',
      (false, _) => 'Следующая карта $map. До смены $minutes мин.',
    };
