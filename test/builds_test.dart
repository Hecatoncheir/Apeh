import 'dart:convert';

import 'package:apeh/builds/build_guides.dart';
import 'package:apeh/builds/guide_publication.dart';
import 'package:apeh/builds/guide_repository.dart';
import 'package:apeh/builds/upgrade_repository.dart';
import 'package:apeh/main.dart';
import 'package:apeh/weapons/weapon.dart';
import 'package:apeh/weapons/weapon_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String bundledJson;
  late Map<String, LegendGuide> legendGuides;

  setUpAll(() async {
    bundledJson = await rootBundle.loadString('assets/legend-guides.json');
    legendGuides = GuideEdition.parse(bundledJson).entries
        .map((id, entry) => MapEntry(id, entry.guide));
  });

  void mockBundledAsset(WidgetTester tester) {
    const path = 'assets/legend-guides.json';
    rootBundle.evict(path);
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async =>
          message != null && utf8.decode(message.buffer.asUint8List()) == path
          ? ByteData.sublistView(utf8.encode(bundledJson))
          : null,
    );
    addTearDown(() => rootBundle.evict(path));
  }

  Weapon weapon(String id, String name) => Weapon.fromJson({
    'slug': id,
    'name': name,
    'categoryCode': 'marksman',
    'damage': 25,
    'projectilesPerShot': 1,
    'ammoPerShot': 1,
    'magazines': {'base': 20},
    'fireModes': [
      {'slug': 'base', 'roundsPerSecond': 6},
    ],
  });

  test('Новый номер выпуска появляется только при изменении подборок', () {
    final draft = jsonDecode(bundledJson) as Map<String, dynamic>;
    draft['patch'] = 'Новая подпись';
    expect(prepareGuideUpdate(bundledJson, jsonEncode(draft)), isNull);
    draft['weaponPairs'][0]['reason'] = 'Новое пояснение к паре.';
    draft['legends']['crypto']['level2'][0]['reason'] = 'Совет после патча.';
    final result = prepareGuideUpdate(bundledJson, jsonEncode(draft))!;
    final edition = GuideEdition.parse(result);
    expect(edition.revision, (draft['revision'] as int) + 1);
    expect(edition.weaponPairs.first.reason, 'Новое пояснение к паре.');
    expect(
      edition.entries['crypto']!.guide.levelTwo.recommended.reason,
      'Совет после патча.',
    );
    expect(
      () => prepareGuideUpdate(result, jsonEncode(draft)),
      throwsFormatException,
    );
  });

  test('Читает старый выпуск и проверяет пары оружия в новых выпусках', () {
    final content = jsonDecode(bundledJson) as Map<String, dynamic>;
    final pairs = content.remove('weaponPairs') as List<dynamic>;
    expect(
      () => GuideEdition.parse(jsonEncode(content)),
      throwsFormatException,
    );
    final revision = content['revision'];
    content['revision'] = 1;
    expect(GuideEdition.parse(jsonEncode(content)).weaponPairs, isEmpty);
    content['revision'] = revision;

    final first = pairs.first as Map<String, dynamic>;
    final invalidLists = [
      pairs.where((pair) => pair['range'] != 'close').toList(),
      [
        ...pairs,
        {...first, 'first': first['second'], 'second': first['first']},
      ],
      [
        ...pairs.skip(1),
        {...first, 'second': first['first']},
      ],
      [
        ...pairs.skip(1),
        {...first, 'range': 'unknown'},
      ],
      [
        ...pairs.skip(1),
        {...first, 'first': ''},
      ],
      [
        ...pairs.skip(1),
        {...first, 'reason': ' '},
      ],
    ];
    for (final invalid in invalidLists) {
      content['weaponPairs'] = invalid;
      expect(
        () => GuideEdition.parse(jsonEncode(content)),
        throwsFormatException,
      );
    }
    content['weaponPairs'] = pairs;
    expect(
      GuideEdition.parse(jsonEncode(content)).weaponPairs
          .map((pair) => pair.range),
      containsAll(BuildRange.values),
    );
  });

  test('У каждой легенды два подписанных стиля на обоих уровнях', () {
    expect(
      legendGuides.keys,
      unorderedEquals(buildLegends.map((legend) => legend.id)),
    );
    for (final entry in legendGuides.entries) {
      final guide = entry.value;
      expect(guide.playStyle.trim(), isNotEmpty, reason: entry.key);
      expect(guide.alternativeStyle.trim(), isNotEmpty, reason: entry.key);
      expect(guide.alternativeStyle, isNot(guide.playStyle), reason: entry.key);
      expect(guide.upgradeNames.toSet(), hasLength(4), reason: entry.key);
      expect([guide.levelTwo.level, guide.levelThree.level], [2, 3]);
      for (final level in [guide.levelTwo, guide.levelThree]) {
        expect(level.recommended.name.trim(), isNotEmpty, reason: entry.key);
        expect(level.recommended.reason.trim(), isNotEmpty, reason: entry.key);
        expect(level.alternative.name.trim(), isNotEmpty, reason: entry.key);
        expect(level.alternative.reason.trim(), isNotEmpty, reason: entry.key);
      }
    }
  });

  test('Старое улучшение Alter в справочнике не скрывает рекомендации', () {
    final guide = legendGuides['alter']!;
    final upgrades = [
      for (final name in guide.upgradeNames) LegendUpgrade(name, 'Описание'),
      const LegendUpgrade('Multidimensional', 'Старое улучшение'),
    ];
    expect(UpgradeCatalog('', upgrades).matches(guide), isTrue);
    expect(
      UpgradeCatalog('', [
        ...upgrades,
        const LegendUpgrade('New perk', 'Новое улучшение'),
      ]).matches(guide),
      isFalse,
    );
  });

  test('Читает только улучшения выбранной легенды и замечает смену набора', () {
    final guide = legendGuides['lifeline']!;
    final rows = [
      for (final name in guide.upgradeNames)
        '<div class="slab"><h3>$name</h3><p>Effect</p></div>',
    ].join();
    final page =
        '''
      <main><h1>Lifeline</h1>
        <section><h2>Abilities</h2><div class="slab"><h3>Other</h3><p>Other</p></div></section>
        <section><h2>Upgrades</h2>$rows</section>
      </main><footer>updated 2026-11-10</footer>
    ''';
    final catalog = parseUpgradeCatalog((page, 'Lifeline'));
    expect(catalog.published, '2026-11-10');
    expect(catalog.matches(guide), isTrue);
    expect(
      parseUpgradeCatalog((
        page.replaceFirst('Revive Shield', 'New perk'),
        'Lifeline',
      )).matches(guide),
      isFalse,
    );
    expect(() => parseUpgradeCatalog((page, 'Crypto')), throwsFormatException);
  });

  test('Проверяет формат и хранит последний принятый выпуск', () async {
    SharedPreferences.setMockInitialValues({});
    final baseline = GuideEdition.parse(bundledJson);
    final next = jsonDecode(bundledJson) as Map<String, dynamic>;
    next['revision'] = baseline.revision + 1;
    next['patch'] = 'Проверочный патч';
    final rows = next['legends'] as Map<String, dynamic>;
    rows['new-legend'] = {...rows['ash'] as Map, 'name': 'New Legend'};
    var body = jsonEncode(next);
    var status = 200;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], isNull);
      expect(request.url.host, 'gist.githubusercontent.com');
      return http.Response.bytes(utf8.encode(body), status);
    });
    addTearDown(client.close);
    final repo = GuideRepository(client);
    final updated = (await repo.update(baseline))!;
    expect(updated.revision, baseline.revision + 1);
    expect(updated.entries['new-legend']!.legend.name, 'New Legend');
    expect((await GuideRepository(client).read())!.patch, 'Проверочный патч');

    body = bundledJson;
    expect(await repo.update(updated), isNull);

    next['revision'] = updated.revision + 1;
    final pairs = next.remove('weaponPairs');
    body = jsonEncode(next);
    await expectLater(repo.update(updated), throwsFormatException);
    next['weaponPairs'] = pairs;
    rows.remove('new-legend');
    body = jsonEncode(next);
    await expectLater(repo.update(updated), throwsFormatException);
    rows.remove('ash');
    body = jsonEncode(next);
    await expectLater(repo.update(updated), throwsFormatException);
    body = '<html>error</html>';
    await expectLater(repo.update(updated), throwsFormatException);
    status = 503;
    await expectLater(repo.update(updated), throwsFormatException);
    expect((await repo.read())!.revision, updated.revision);
    expect((await repo.read())!.entries, contains('new-legend'));
    expect(
      (await repo.read())!.weaponPairs.map((pair) => pair.title),
      orderedEquals(updated.weaponPairs.map((pair) => pair.title)),
    );
  });

  testWidgets('Обновляет рекомендации по кнопке и открывает их офлайн', (
    tester,
  ) async {
    mockBundledAsset(tester);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1080, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final next = jsonDecode(bundledJson) as Map<String, dynamic>;
    next['revision'] = (next['revision'] as int) + 1;
    next['patch'] = 'Проверочный патч';
    next['legends']['lifeline']['level2'][0]['name'] = 'Test Radio';
    final pairs = next['weaponPairs'] as List<dynamic>;
    pairs.removeWhere((pair) => pair['range'] == 'medium');
    pairs.add({
      'range': 'medium',
      'first': 'r-301',
      'second': 'flatline',
      'title': 'R-301 + Flatline',
      'reason': 'Пояснение из нового выпуска.',
    });
    var response = bundledJson;
    var online = true;
    final client = MockClient((request) async {
      if (online && request.url.host == 'gist.githubusercontent.com') {
        return http.Response.bytes(utf8.encode(response), 200);
      }
      return http.Response('', 503);
    });
    addTearDown(client.close);
    await WeaponRepository(client).save(
      WeaponCatalog('Cipher', DateTime(2026, 11, 4), [
        weapon('r-301', 'R-301 Carbine'),
        weapon('flatline', 'VK-47 Flatline'),
      ]),
    );

    Future<void> openBuilds() async {
      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сборки'));
      await tester.pumpAndSettle();
    }

    await openBuilds();
    expect(find.text('Новых выпусков нет.'), findsOneWidget);
    expect(find.text('R-301 + Volt'), findsOneWidget);
    response = jsonEncode(next);
    await tester.tap(find.text('Проверить обновления'));
    await tester.pumpAndSettle();
    expect(find.text('Рекомендации обновлены.'), findsOneWidget);
    expect(find.text('R-301 + Volt'), findsNothing);
    expect(find.text('R-301 + Flatline'), findsOneWidget);
    expect(
      find.text('Проверочный патч · выпуск ${next['revision']}'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());

    online = false;
    await openBuilds();
    expect(
      find.text('Проверочный патч · выпуск ${next['revision']}'),
      findsOneWidget,
    );
    expect(find.textContaining('Открыт выпуск с устройства.'), findsOneWidget);
    expect(find.text('Test Radio'), findsOneWidget);
    expect(find.text('Пояснение из нового выпуска.'), findsOneWidget);
    await tester.tap(find.text('Сравнить оружие'));
    await tester.pumpAndSettle();
    expect(find.text('Сравнение оружия'), findsOneWidget);
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'R-301 Carbine'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'VK-47 Flatline'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Сборка и затронувшие её изменения доступны офлайн', (
    tester,
  ) async {
    mockBundledAsset(tester);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1080, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final draft = jsonDecode(bundledJson) as Map<String, dynamic>;
    draft['patchHighlights']['title'] = 'Проверочная сводка';
    draft['patchHighlights']['changes'] = [
      {
        'section': 'weapons',
        'id': 'r-301',
        'name': 'R-301',
        'ru': 'Проверочное изменение урона.',
        'en': 'Test damage change.',
      },
    ];
    final digestOnly = prepareGuideUpdate(bundledJson, jsonEncode(draft));
    expect(digestOnly, isNotNull);
    draft['legends']['lifeline']['level2'][0]['name'] = 'New Radio';
    final next = prepareGuideUpdate(bundledJson, jsonEncode(draft))!;
    var response = bundledJson;
    var online = true;
    final client = MockClient((request) async {
      if (online && request.url.host == 'gist.githubusercontent.com') {
        return http.Response.bytes(utf8.encode(response), 200);
      }
      return http.Response('', 503);
    });
    addTearDown(client.close);
    await WeaponRepository(client).save(
      WeaponCatalog('Cipher', DateTime(2026, 11, 4), [
        weapon('r-301', 'R-301 Carbine'),
        weapon('volt', 'Volt SMG'),
      ]),
    );

    Future<void> openBuilds() async {
      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сборки'));
      await tester.pumpAndSettle();
    }

    await openBuilds();
    await tester.tap(find.text('Новая сборка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Мой BR');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Мой BR'), findsOneWidget);
    response = next;
    final refresh = find.text('Проверить обновления');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());

    online = false;
    await openBuilds();
    expect(find.text('Мой BR'), findsOneWidget);
    expect(
      find.textContaining('Enhanced Radio · Нет на этом уровне'),
      findsOneWidget,
    );
    final highlight = find.textContaining(
      'Что изменилось в патче · Проверочная сводка',
    );
    await tester.tap(highlight);
    await tester.pumpAndSettle();
    expect(find.text('Проверочное изменение урона.'), findsOneWidget);
    final compare = find.text('Сравнить оружие').first;
    await tester.ensureVisible(compare);
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'R-301 Carbine'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'Volt SMG'),
      findsOneWidget,
    );
    await tester.tap(find.text('Что изменилось в патче'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AlertDialog, 'Проверочная сводка'),
      findsOneWidget,
    );
    expect(find.text('Проверочное изменение урона.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Дальняя пара открывает два нужных ствола в сравнении', (
    tester,
  ) async {
    mockBundledAsset(tester);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1080, 880));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      expect(request.headers['authorization'], isNull);
      return http.Response('', 503);
    });
    addTearDown(client.close);

    await WeaponRepository(client).save(
      WeaponCatalog('Cipher', DateTime(2026, 11, 4), [
        weapon('r-301', 'R-301 Carbine'),
        weapon('flatline', 'VK-47 Flatline'),
        weapon('g7-scout', 'G7 Scout'),
        weapon('car', 'C.A.R. SMG'),
      ]),
    );
    await tester.pumpWidget(ApehApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сборки'));
    await tester.pumpAndSettle();

    expect(find.text('Enhanced Radio'), findsOneWidget);
    expect(find.text('Revive Shield'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мобильная поддержка').last);
    await tester.pumpAndSettle();
    expect(find.text('Improved Flight'), findsOneWidget);
    expect(find.text('Ultimate Cooldown'), findsOneWidget);
    await tester.tap(find.text('Lifeline'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Seer'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Seer').last);
    await tester.pumpAndSettle();
    expect(find.text('Lasting Beats'), findsOneWidget);
    expect(find.text('Home Base'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поиск и преследование').last);
    await tester.pumpAndSettle();
    expect(find.text('Energizing Focus'), findsOneWidget);
    expect(find.text('Split Focus'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(360, 850));
    await tester.pumpAndSettle();
    expect(find.text('Сборки для BR'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(1080, 880));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<BuildRange>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальняя').last);
    await tester.pumpAndSettle();
    expect(find.text('G7 Scout + C.A.R.'), findsOneWidget);
    await tester.tap(find.text('Сравнить оружие').first);
    await tester.pumpAndSettle();
    expect(find.text('Сравнение оружия'), findsOneWidget);
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'G7 Scout'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownButton<Weapon>, 'C.A.R. SMG'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
