import 'rotation.dart';

RotationSnapshot demoRotation(DateTime now) {
  PlaylistRotation sample(
    String current,
    String next,
    int minutes, {
    String? currentVariant,
    String? nextVariant,
  }) {
    final change = now.add(Duration(minutes: minutes));
    return PlaylistRotation(
      current: MapSlot(
        name: current,
        start: now.subtract(const Duration(minutes: 7)),
        end: change,
        variant: currentVariant,
      ),
      next: MapSlot(
        name: next,
        start: change,
        end: change.add(const Duration(minutes: 30)),
        variant: nextVariant,
      ),
    );
  }

  return RotationSnapshot(
    updatedAt: now,
    playlists: {
      Playlist.ranked: sample('Storm Point', 'Broken Moon', 96),
      Playlist.battleRoyale: sample('E-District', 'Storm Point', 41),
      Playlist.mixtape: sample(
        'Thunderdome',
        'Production Yard',
        8,
        currentVariant: 'TDM',
        nextVariant: 'Control',
      ),
      Playlist.wildcard: sample('Broken Moon', 'E-District', 22),
    },
  );
}
