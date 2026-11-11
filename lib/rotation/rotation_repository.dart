import 'dart:convert';

import 'package:http/http.dart' as http;

import 'public_rotation.dart';
import 'rotation.dart';

class RotationApi {
  RotationApi(this._client);

  final http.Client _client;
  static final _endpoint = Uri.https(
    'api.apexlegendsstatus.com',
    '/maprotation',
    {'version': '2'},
  );

  Future<Map<String, Object?>> fetch(String key) async {
    final response = await _client
        .get(_endpoint, headers: {'Authorization': key})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final code = response.statusCode;
      throw RotationException(switch (code) {
        401 || 403 || 404 => 'Apex Legends Status не принял ключ API.',
        429 => 'Слишком много запросов. Попробуйте обновить позже.',
        _ => 'Apex Legends Status вернул ошибку HTTP $code.',
      }, canRetry: code != 401 && code != 403 && code != 404);
    }
    final Object? payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, Object?>) throw const FormatException();
    return payload;
  }

  Future<RotationSnapshot> fetchPublic() async {
    final response = await _client
        .get(publicRotationUri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw RotationException(
        'Страница расписания вернула ошибку HTTP ${response.statusCode}.',
        canRetry: true,
      );
    }
    return parsePublicRotation(utf8.decode(response.bodyBytes), DateTime.now());
  }
}

class RotationException implements Exception {
  const RotationException(this.message, {required this.canRetry});
  final String message;
  final bool canRetry;
}

class RotationRepository {
  RotationRepository(this._api);

  final RotationApi _api;

  Future<RotationSnapshot> load(String key) async {
    final payload = await _api.fetch(key);
    return parseRotation(payload, DateTime.now());
  }

  Future<RotationSnapshot> loadPublic() => _api.fetchPublic();
}

String encodeRotationSnapshot(RotationSnapshot snapshot) => jsonEncode({
  'updatedAt': snapshot.updatedAt.toUtc().toIso8601String(),
  'rotation': {
    for (final MapEntry(:key, :value) in snapshot.playlists.entries)
      (key == Playlist.battleRoyale ? 'battle_royale' : key.name): {
        if (value.current case final slot?) 'current': _encodeSlot(slot),
        if (value.next case final slot?) 'next': _encodeSlot(slot),
        'later': value.later.map(_encodeSlot).toList(),
      },
  },
});

Map<String, Object?> _encodeSlot(MapSlot slot) => {
  'map': slot.name,
  'start': slot.start.millisecondsSinceEpoch ~/ 1000,
  'end': slot.end.millisecondsSinceEpoch ~/ 1000,
  'asset': ?slot.image?.toString(),
  'eventName': ?slot.variant,
};

RotationSnapshot decodeRotationSnapshot(String value) {
  final Object? payload = jsonDecode(value);
  if (payload case {
    'updatedAt': final String timestamp,
    'rotation': final Map<String, Object?> rotation,
  }) {
    final updatedAt = DateTime.tryParse(timestamp);
    if (updatedAt != null) return parseRotation(rotation, updatedAt);
  }
  throw const FormatException();
}

RotationSnapshot parseRotation(
  Map<String, Object?> payload,
  DateTime updatedAt,
) {
  return RotationSnapshot(
    updatedAt: updatedAt,
    playlists: {
      for (final mode in Playlist.values) mode: ?_findRotation(mode, payload),
    },
  );
}

PlaylistRotation? _findRotation(Playlist mode, Map<String, Object?> payload) {
  final keys = switch (mode) {
    Playlist.ranked => ['ranked', 'br_ranked'],
    Playlist.battleRoyale => ['battle_royale', 'pubs'],
    Playlist.mixtape => ['mixtape', 'ltm'],
    Playlist.wildcard => ['wildcard', 'freestyle'],
  };
  for (final key in keys) {
    final rotation = _parseSection(payload[key]);
    if (rotation == null) continue;
    if (key != 'ltm' ||
        _isMixtape(rotation.current) ||
        _isMixtape(rotation.next)) {
      return rotation;
    }
  }
  return null;
}

PlaylistRotation? _parseSection(Object? section) {
  if (section is! Map<String, Object?>) return null;
  final current = _slot(section['current']);
  final next = _slot(section['next']);
  if (current == null && next == null) return null;
  final later = section['later'];
  return PlaylistRotation(
    current: current,
    next: next,
    later: later is List<Object?>
        ? List.unmodifiable(later.map(_slot).nonNulls)
        : const [],
  );
}

MapSlot? _slot(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final name = _text(value['map']);
  final start = rotationTime(value['start']);
  final end = rotationTime(value['end']);
  if (name == null || start == null || end == null || !end.isAfter(start)) {
    return null;
  }
  final image = Uri.tryParse(_text(value['asset']) ?? '');
  return MapSlot(
    name: name,
    start: start,
    end: end,
    image: image != null && image.scheme == 'https' && image.host.isNotEmpty
        ? image
        : null,
    variant: _text(value['eventName']) ?? _text(value['mode']),
  );
}

bool _isMixtape(MapSlot? slot) {
  final label = '${slot?.name ?? ''} ${slot?.variant ?? ''}'.toLowerCase();
  return const [
    'mixtape',
    'gun run',
    'control',
    'tdm',
    'deathmatch',
    'lockdown',
  ].any(label.contains);
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
