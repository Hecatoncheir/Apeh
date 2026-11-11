import 'dart:convert';

import 'package:apeh/rotation/public_rotation.dart';
import 'package:apeh/rotation/rotation.dart';
import 'package:apeh/rotation/rotation_repository.dart';
import 'package:apeh/rotation/rotation_time_zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'rotation_page_fixture.dart';

void main() {
  test('Часовой пояс учитывает сезонный сдвиг и сохраняет момент смены', () {
    final zone = RotationTimeZone.fromId('America/New_York');
    final before = DateTime.utc(2026, 3, 8, 6, 59);
    final after = DateTime.utc(2026, 3, 8, 7);
    expect(zone.at(before).hour, 1);
    expect(zone.at(after).hour, 3);
    expect(
      zone.at(after).difference(zone.at(before)),
      const Duration(minutes: 1),
    );
    expect(RotationTimeZone.fromId('unknown'), RotationTimeZone.device);
  });

  final start = DateTime.utc(2026, 11, 11, 10);
  final change = start.add(const Duration(minutes: 15));
  final end = change.add(const Duration(minutes: 15));

  Map<String, Object> slot(String map, DateTime from, DateTime to) => {
    'map': map,
    'start': from.millisecondsSinceEpoch ~/ 1000,
    'end': to.millisecondsSinceEpoch ~/ 1000,
  };

  test('Разбор ротации v2 и смена по абсолютному времени', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters, {'version': '2'});
      expect(request.headers['authorization'], 'test-key');
      final section = {
        'current': slot('Storm Point', start, change),
        'next': slot('Broken Moon', change, end),
      };
      return http.Response(
        jsonEncode({
          'battle_royale': section,
          'ranked': section,
          'wildcard': {'current': false, 'next': section['next']},
          'ltm': {
            'current': {
              ...slot('Thunderdome', start, change),
              'eventName': 'Control',
            },
          },
        }),
        200,
      );
    });
    addTearDown(client.close);

    final snapshot = await RotationRepository(RotationApi(client))
        .load('test-key');
    expect(snapshot.playlists.keys, unorderedEquals(Playlist.values));

    final ranked = snapshot.playlists[Playlist.ranked]!;
    expect(ranked.activeAt(start)?.name, 'Storm Point');
    expect(ranked.upcomingAt(start)?.name, 'Broken Moon');
    expect(ranked.activeAt(change)?.name, 'Broken Moon');
    expect(ranked.activeAt(end), isNull);
    expect(ranked.upcomingAt(change), isNull);
    expect(snapshot.playlists[Playlist.mixtape]?.current?.variant, 'Control');
    expect(snapshot.playlists[Playlist.wildcard]?.activeAt(start), isNull);
    expect(
      snapshot.playlists[Playlist.wildcard]?.upcomingAt(start)?.name,
      'Broken Moon',
    );
  });

  test('Стороннее событие не становится ротацией Mixtape', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'ltm': {'current': slot('Godzilla Attacks', start, change)},
        }),
        200,
      ),
    );
    addTearDown(client.close);

    final snapshot = await RotationRepository(RotationApi(client))
        .load('test-key');
    expect(snapshot.playlists, isEmpty);
  });

  test('API распознаёт ответ 404 для неизвестного ключа', () async {
    final client = MockClient(
      (_) async => http.Response("Error: API key doesn't exist !", 404),
    );
    addTearDown(client.close);

    await expectLater(
      RotationApi(client).fetch('test-key'),
      throwsA(
        isA<RotationException>().having(
          (error) => error.canRetry,
          'canRetry',
          isFalse,
        ),
      ),
    );
  });

  test('Публичная страница сохраняет интервалы и подписи всех режимов', () {
    final parsed = parsePublicRotation(
      rotationPageFixture(start, images: true),
      start,
    );
    final restored = decodeRotationSnapshot(encodeRotationSnapshot(parsed));
    expect(restored.updatedAt, start);
    expect(restored.playlists.keys, unorderedEquals(Playlist.values));
    final mixtape = restored.playlists[Playlist.mixtape]!;
    final wildcard = restored.playlists[Playlist.wildcard]!;
    expect(mixtape.activeAt(start)?.variant, 'Gun Run');
    expect(mixtape.activeAt(start)?.image?.path, '/assets/maps/map.png');
    expect(mixtape.upcomingAt(start)?.name, 'Thunderdome');
    expect(
      mixtape.upcomingAt(start)?.start,
      start.add(const Duration(minutes: 10)),
    );
    expect(
      mixtape.activeAt(start.add(const Duration(minutes: 26)))?.name,
      'Следующая после неё',
    );
    expect(mixtape.activeAt(start.add(const Duration(hours: 1))), isNull);
    expect(wildcard.activeAt(start)?.variant, 'Godzilla Attacks');
    expect(
      wildcard.upcomingAt(start)?.start,
      start.add(const Duration(days: 20, hours: 7)),
    );
  });
}
