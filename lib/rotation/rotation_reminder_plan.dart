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
  DateTime now,
) {
  final reminders = <int, MapReminder>{};
  for (final mode in settings.playlists) {
    final rotation = snapshot?.playlists[mode];
    if (rotation == null) continue;
    for (final slot in rotation.slots) {
      final changeAt = slot.start.toUtc();
      final fireAt = changeAt.subtract(Duration(minutes: settings.minutes));
      if (!fireAt.isAfter(now)) continue;
      final previous = rotation.activeAt(
        changeAt.subtract(const Duration(milliseconds: 1)),
      );
      if (previous != null &&
          previous.name == slot.name &&
          previous.variant == slot.variant) {
        continue;
      }
      final seconds = changeAt.millisecondsSinceEpoch ~/ 1000;
      final id = _firstId + ((seconds & _secondsMask) << 2) + mode.index;
      final map = [slot.name, slot.variant].nonNulls.join(' · ');
      reminders[id] = (
        id: id,
        fireAt: fireAt,
        changeAt: changeAt,
        title: 'Apeh · ${mode.label}',
        body: settings.minutes == 0
            ? 'Карта меняется на $map.'
            : 'Следующая карта $map. До смены ${settings.minutes} мин.',
      );
    }
  }
  final ordered = reminders.values.toList()
    ..sort((a, b) {
      final byTime = a.fireAt.compareTo(b.fireAt);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });
  return ordered.take(48).toList(growable: false);
}
