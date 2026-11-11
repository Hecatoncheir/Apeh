import 'package:html/dom.dart';
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
  return RotationSnapshot(
    updatedAt: updatedAt,
    playlists: {
      for (final mode in Playlist.values)
        mode: _parseCard(mode, _findCard(mode, cards), styles),
    },
  );
}

Element _findCard(Playlist mode, List<Element> cards) {
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
  return card ?? (throw const FormatException());
}

PlaylistRotation _parseCard(Playlist mode, Element card, String styles) {
  final current = _currentSlot(mode, card, styles);
  final upcoming =
      card
          .querySelectorAll('.curmap-next-map')
          .map((row) => _upcomingSlot(mode, row))
          .nonNulls
          .toList()
        ..sort((first, second) => first.start.compareTo(second.start));
  if (current == null && upcoming.isEmpty) throw const FormatException();
  return PlaylistRotation(
    current: current,
    next: upcoming.firstOrNull,
    later: List.unmodifiable(upcoming.skip(1)),
  );
}

MapSlot? _currentSlot(Playlist mode, Element card, String styles) {
  final container = card.querySelector('.container');
  if (container == null) return null;
  final timer = container.querySelector('[data-start][data-end]');
  final style = container.classes
      .where((name) => name != 'container')
      .map(
        (name) =>
            RegExp(r'\.' + RegExp.escape(name) + r'\s*\{([^}]+)\}')
                .firstMatch(styles)
                ?.group(1),
      )
      .nonNulls
      .firstOrNull;
  return _slot(
    mode,
    container.querySelector('h2')?.text,
    timer?.attributes['data-start'],
    timer?.attributes['data-end'],
    style,
  );
}

MapSlot? _upcomingSlot(Playlist mode, Element row) {
  final times = row.querySelectorAll('[data-tz]');
  if (times.length < 2) return null;
  return _slot(
    mode,
    row.querySelector('h4')?.text,
    times[0].attributes['data-tz'],
    times[1].attributes['data-tz'],
    row.attributes['style'],
  );
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
  return MapSlot(
    name: parts.first,
    variant: parts.length > 1 ? parts.skip(1).join(' - ') : null,
    start: start,
    end: end,
    image: _publicImage(style),
  );
}

Uri? _publicImage(String? style) {
  final path = _imageUrl.firstMatch(style ?? '')?.group(1);
  if (path == null) return null;
  final reference = Uri.tryParse(path);
  if (reference == null) return null;
  final image = publicRotationUri.resolveUri(reference);
  return image.scheme == 'https' && image.host == publicRotationUri.host
      ? image
      : null;
}
