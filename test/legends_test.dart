import 'package:apeh/legends/legend_repository.dart';
import 'package:apeh/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rotation_page_fixture.dart';

String _board(String pathfinder) =>
    '''
<div class="legends-banner__item">
  <img class="legends-banner__image" alt="Pathfinder">
  <div class="legends-banner__content">
    Pathfinder<br><span>$pathfinder%</span><span>8.2%</span>
  </div>
</div>
<div class="legends-banner__item">
  <img class="legends-banner__image" alt="Loba">
  <div class="legends-banner__content">
    Loba<br><span>7.1%</span><span>1.5%</span>
  </div>
</div>
''';

const _history = '''
[
  {"name":"Date","data":["2026-09-01","2026-11-03","2026-11-03","2026-11-08","2026-11-10"]},
  {"name":"Pathfinder","data":[9,11,12,null,17.2]},
  {"name":"Loba","data":[8,6.5,7,6.5,6.9]}
]
''';

void main() {
  test('Различает текущую долю и изменение, сохраняет пропуски в истории', () {
    final picks = parsePicks(
      _board('17,4'),
      Uri.https('apexlegendsstatus.com'),
    );
    expect(picks.first.name, 'Pathfinder');
    expect(picks.first.percent, 17.4);
    final history = parsePickHistory(_history);
    final points = history['Pathfinder']!;
    expect(points.map((point) => point.day.day), [3, 10]);
    expect(points.map((point) => point.percent), [12, 17.2]);
  });

  testWidgets('Фильтр «Алмаз» загружает свою историю без ключа', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1040, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = <String>[];
    var offline = false;
    final client = MockClient((request) async {
      expect(request.headers['authorization'], isNull);
      final path = request.url.path;
      paths.add(path);
      if (offline) return http.Response('', 503);
      if (path == '/current-map') {
        return http.Response(
          rotationPageFixture(DateTime.now()),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      if (path.startsWith('/lib/legendtrend')) {
        return http.Response(_history, 200);
      }
      return http.Response(
        _board(path.endsWith('/Diamond') ? '17.4' : '12.3') +
            List.generate(
              28,
              (index) =>
                  '''
<div class="legends-banner__item">
  <img class="legends-banner__image" alt="Legend $index">
  <div class="legends-banner__content">Legend $index<br><span>1%</span></div>
</div>
''',
            ).join(),
        200,
      );
    });
    addTearDown(client.close);

    Future<void> openLegends() async {
      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Легенды'));
      await tester.pumpAndSettle();
    }

    await openLegends();
    expect(find.text('12,30%'), findsOneWidget);
    await tester.tap(find.text('Все игроки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Алмаз').last);
    await tester.pumpAndSettle();
    expect(paths, contains('/lib/legendtrend_diamond.json'));
    expect(find.text('17,40%'), findsOneWidget);
    expect(find.text('+5,20 п. п. за 7 дней'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('Loba')));
    await tester.pumpAndSettle();
    expect(find.text('−0,10 п. п. за 7 дней'), findsOneWidget);
    final pathfinder = tester.getTopLeft(
      find.byKey(const ValueKey('Pathfinder')),
    );
    final loba = tester.getTopLeft(find.byKey(const ValueKey('Loba')));
    expect(pathfinder.dy, loba.dy);
    expect(pathfinder.dx, lessThan(loba.dx));
    final lowerCard = find.byKey(const ValueKey('Legend 9'));
    final beforeScroll = tester.getTopLeft(lowerCard);
    expect(beforeScroll.dy, greaterThan(loba.dy));
    final chart = find.text('Динамика выбора');
    final chartPosition = tester.getTopLeft(chart);
    final grid = find.byKey(const ValueKey('legend-pick-grid'));
    final chartCard = find.ancestor(of: chart, matching: find.byType(Card));
    final gridCard = find.ancestor(of: grid, matching: find.byType(Card));
    expect(
      tester.getSize(chartCard).height,
      lessThan(tester.getSize(gridCard).height),
    );
    await tester.drag(grid, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(lowerCard).dy, lessThan(beforeScroll.dy));
    expect(tester.getTopLeft(chart), chartPosition);
    await tester.binding.setSurfaceSize(const Size(360, 850));
    await tester.pumpAndSettle();
    expect(find.text('−0,10 п. п. за 7 дней'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    offline = true;
    await openLegends();
    expect(find.text('12,30%'), findsOneWidget);
    expect(
      find.textContaining('Apex Legends Status · сохранено'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
