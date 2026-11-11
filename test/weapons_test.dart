import 'dart:convert';

import 'package:apeh/main.dart';
import 'package:apeh/weapons/weapon.dart';
import 'package:apeh/weapons/weapon_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _profile({
  required String id,
  required num damage,
  required num rate,
  required int magazine,
  int? extended,
  int pellets = 1,
  int ammoPerShot = 1,
  int? burst,
  double? pause,
  double? rechamber,
  double? shieldScale,
}) => {
  'slug': id,
  'name': id,
  'categoryCode': 'smg',
  'ammoTypeCodes': ['light'],
  'damage': damage,
  'projectilesPerShot': pellets,
  'ammoPerShot': ammoPerShot,
  'magazines': {'base': magazine, 'level3': extended},
  'rechamberSeconds': rechamber,
  'shieldDamageScale': shieldScale,
  'fireModes': [
    {
      'slug': 'base',
      'roundsPerSecond': rate,
      'burstCount': burst,
      'burstDelaySeconds': pause,
    },
  ],
};

void main() {
  test('R-99 пересчитывает время по броне и вместимости магазина', () {
    final r99 = Weapon.fromJson(
      _profile(id: 'r-99', damage: 12, rate: 18, magazine: 18, extended: 27),
    );
    expect(r99.estimate(Armor.white, extended: false).shots, 13);
    expect(
      r99.estimate(Armor.purple, extended: false).seconds,
      closeTo(0.889, .001),
    );
    final red = r99.estimate(Armor.mythic, extended: false);
    expect(red.shots, 19);
    expect(red.seconds, isNull);
    expect(
      r99.estimate(Armor.mythic, extended: true).seconds,
      closeTo(1, .001),
    );
  });

  test('Пауза между очередями и передёргивание затвора входят в TTK', () {
    final prowler = Weapon.fromJson(
      _profile(
        id: 'prowler',
        damage: 16,
        rate: 21,
        magazine: 20,
        burst: 5,
        pause: .23,
      ),
    );
    expect(
      prowler.estimate(Armor.purple, extended: false).seconds,
      closeTo(.936, .001),
    );
    final kraber = Weapon.fromJson(
      _profile(
        id: 'kraber',
        damage: 150,
        rate: 1.2,
        magazine: 4,
        rechamber: 1.6,
      ),
    );
    expect(kraber.estimate(Armor.white, extended: false).seconds, 0);
    expect(kraber.estimate(Armor.purple, extended: false).seconds, 1.6);
  });

  test(
    'Учитывает попадания дробью, усиление против щита и расход патронов',
    () {
      final eva = Weapon.fromJson(
        _profile(
          id: 'eva-8-disruptor',
          damage: 7,
          rate: 2.8,
          magazine: 8,
          pellets: 8,
          shieldScale: 1.2,
        ),
      );
      expect(eva.bodyDamage, 56);
      expect(eva.estimate(Armor.blue, extended: false).shots, 3);
      final alternator = Weapon.fromJson(
        _profile(
          id: 'alternator-dual',
          damage: 14,
          rate: 7.75,
          magazine: 14,
          pellets: 2,
          ammoPerShot: 2,
        ),
      );
      expect(alternator.estimate(Armor.purple, extended: false).shots, 8);
      expect(
        alternator.estimate(Armor.purple, extended: false).seconds,
        isNull,
      );
    },
  );

  testWidgets('Сохранённый каталог позволяет сравнить оружие при сбое сети', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1040, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      expect(request.headers['authorization'], isNull);
      return http.Response('', 503);
    });
    addTearDown(client.close);
    final catalog = WeaponCatalog('Cipher', DateTime(2026, 11, 4), [
      Weapon.fromJson(
        _profile(id: 'r-301', damage: 15, rate: 13.5, magazine: 21),
      ),
      Weapon.fromJson(
        _profile(id: 'flatline', damage: 20, rate: 10, magazine: 19),
      ),
      Weapon.fromJson(
        _profile(id: 'r-99', damage: 12, rate: 18, magazine: 18, extended: 27),
      ),
    ]);
    await WeaponRepository(client).save(catalog);
    await tester.pumpWidget(ApehApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оружие'));
    await tester.pumpAndSettle();

    expect(find.textContaining('сохранённая копия'), findsOneWidget);
    expect(find.text('0,963 с'), findsOneWidget);
    await tester.tap(find.text('r-301'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('r-99').last);
    await tester.pumpAndSettle();
    expect(find.text('0,889 с'), findsOneWidget);
    await tester.tap(find.text('Красный · мифический · 225'));
    await tester.pumpAndSettle();
    expect(find.text('Нужна перезарядка'), findsOneWidget);
    await tester.tap(find.text('Магазин III уровня'));
    await tester.pumpAndSettle();
    expect(find.text('1,000 с'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Читает дату патча и каталог из нескольких фрагментов страницы', () {
    final payload =
        '1:{"weapons":${jsonEncode([_profile(id: 'R-301 [base]', damage: 15, rate: 13.5, magazine: 21), _profile(id: 'Flatline', damage: 20, rate: 10, magazine: 19)])}}';
    final split = payload.indexOf('R-301');
    String chunk(String data) =>
        '<script>self.__next_f.push([1,${jsonEncode(data)}])</script>';
    final catalog = parseWeaponCatalog('''
      <p class="data-basis"><span>Data baseline · Season 31 Cipher</span>
      <time datetime="2026-11-04">Nov 4, 2026</time></p>
      ${chunk(payload.substring(0, split))}
      ${chunk(payload.substring(split))}
    ''');
    expect(catalog.season, 'Season 31 Cipher');
    expect(catalog.patch, DateTime(2026, 11, 4));
    expect(catalog.weapons.map((weapon) => weapon.id), [
      'Flatline',
      'R-301 [base]',
    ]);
  });
}
