enum Playlist {
  ranked('Ranked'),
  battleRoyale('Обычный BR'),
  mixtape('Mixtape'),
  wildcard('Wildcard');

  const Playlist(this.label);

  final String label;
}

class MapSlot {
  const MapSlot({
    required this.name,
    required this.start,
    required this.end,
    this.image,
    this.variant,
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final Uri? image;
  final String? variant;

  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);
}

class PlaylistRotation {
  const PlaylistRotation({this.current, this.next, this.later = const []});

  final MapSlot? current;
  final MapSlot? next;
  final List<MapSlot> later;

  Iterable<MapSlot> get slots sync* {
    if (current case final slot?) yield slot;
    if (next case final slot?) yield slot;
    yield* later;
  }

  MapSlot? activeAt(DateTime time) =>
      slots.where((slot) => slot.contains(time)).firstOrNull;

  MapSlot? upcomingAt(DateTime time) =>
      slots.where((slot) => time.isBefore(slot.start)).firstOrNull;
}

class RotationSnapshot {
  RotationSnapshot({
    required this.updatedAt,
    required Map<Playlist, PlaylistRotation> playlists,
  }) : playlists = Map.unmodifiable(playlists);

  final DateTime updatedAt;
  final Map<Playlist, PlaylistRotation> playlists;
}

DateTime? rotationTime(Object? value) {
  final seconds = switch (value) {
    final int seconds => seconds,
    final String raw => int.tryParse(raw),
    _ => null,
  };
  if (seconds == null || seconds <= 0 || seconds > 253402300799) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
