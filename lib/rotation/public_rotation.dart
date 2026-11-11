import 'package:html/parser.dart' as html;

import 'rotation.dart';

final publicRotationUri = Uri.https('apexlegendsstatus.com', '/current-map');
final _imageUrl = RegExp(r'''url\(\s*['"]?([^'")\s]+)['"]?\s*\)''');

RotationSnapshot parsePublicRotation(String body, DateTime updatedAt) {
  final document = html.parse(body);
  final styles = document
      .querySelectorAll('style')
      .map((tag) => tag.text)
      .join();
  final cards = document.querySelectorAll('.curmap-overview-card[onclick]');
  final playlists = <Playlist, PlaylistRotation>{};

  for (final mode in Playlist.values) {
    final route = switch (mode) {
      Playlist.ranked => 'battle_royale/ranked',
      Playlist.battleRoyale => 'battle_royale/pubs',
      Playlist.mixtape => 'mixtape/pubs',
      Playlist.wildcard => 'wildcard/pubs',
    };
    final card = cards.where((card) {
      final action = card.attributes['onclick'] ?? '';
      return action.contains("'/current-map/$route'") ||
          action.contains('"/current-map/$route"');
    }).firstOrNull;
    if (card == null) throw const FormatException();

    final container = card.querySelector('.container');
    final timer = container?.querySelector('[data-start][data-end]');
    final style = container?.classes
        .where((name) => name != 'container')
        .map(
          (name) =>
              RegExp(r'\.' + RegExp.escape(name) + r'\s*\{([^}]+)\}')
                  .firstMatch(styles)
                  ?.group(1),
        )
        .nonNulls
        .firstOrNull;
    final current = _slot(
      mode,
      container?.querySelector('h2')?.text,
      timer?.attributes['data-start'],
      timer?.attributes['data-end'],
      style,
    );
    final upcoming = <MapSlot>[];
    for (final row in card.querySelectorAll('.curmap-next-map')) {
      final times = row.querySelectorAll('[data-tz]');
      if (times.length < 2) continue;
      final slot = _slot(
        mode,
        row.querySelector('h4')?.text,
        times[0].attributes['data-tz'],
        times[1].attributes['data-tz'],
        row.attributes['style'],
      );
      if (slot != null) upcoming.add(slot);
    }
    upcoming.sort((first, second) => first.start.compareTo(second.start));
    if (current == null && upcoming.isEmpty) throw const FormatException();
    playlists[mode] = PlaylistRotation(
      current: current,
      next: upcoming.firstOrNull,
      later: List.unmodifiable(upcoming.skip(1)),
    );
  }
  return RotationSnapshot(updatedAt: updatedAt, playlists: playlists);
}

MapSlot? _slot(
  Playlist mode,
  String? label,
  String? from,
  String? to,
  String? style,
) {
  final title = label?.trim() ?? '';
  final start = rotationTime(from);
  final end = rotationTime(to);
  if (title.isEmpty || start == null || end == null || !end.isAfter(start)) {
    return null;
  }
  final parts = switch (mode) {
    Playlist.mixtape || Playlist.wildcard => title.split(' - '),
    _ => [title],
  };
  final imagePath = _imageUrl.firstMatch(style ?? '')?.group(1);
  final imageReference = imagePath == null ? null : Uri.tryParse(imagePath);
  final image = imageReference == null
      ? null
      : publicRotationUri.resolveUri(imageReference);
  return MapSlot(
    name: parts.first,
    variant: parts.length > 1 ? parts.skip(1).join(' - ') : null,
    start: start,
    end: end,
    image: image?.scheme == 'https' && image?.host == publicRotationUri.host
        ? image
        : null,
  );
}
