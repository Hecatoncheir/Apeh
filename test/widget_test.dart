import 'package:apeh/main.dart';
import 'package:apeh/rotation/public_rotation.dart';
import 'package:apeh/rotation/rotation.dart';
import 'package:apeh/rotation/rotation_notifications.dart';
import 'package:apeh/rotation/rotation_reminder_plan.dart';
import 'package:apeh/rotation/rotation_storage.dart';
import 'package:apeh/settings/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rotation_page_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final width in [360.0, 1000.0]) {
    testWidgets('Экран ротации при ширине $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient((request) async {
        expect(request.url, publicRotationUri);
        expect(request.headers['authorization'], isNull);
        return _publicResponse();
      });
      addTearDown(client.close);
      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();

      expect(find.text('Ranked'), findsOneWidget);
      expect(find.text('Обычный BR'), findsOneWidget);
      expect(find.text('Mixtape'), findsOneWidget);
      await tester.tap(find.text('E-District'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Ranked'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Storm Point'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.textContaining('До смены '), findsWidgets);

      await tester.tap(find.byTooltip('Настроить ключ API'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Вставьте ключ API'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Wildcard'));
      await tester.pumpAndSettle();
      expect(find.text('Wildcard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Напоминания выбираются по режимам и восстанавливаются офлайн', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var online = true;
    final initial = _publicResponse();
    var body = initial.body;
    final client = MockClient((_) async {
      return online
          ? http.Response(body, 200, headers: initial.headers)
          : http.Response('', 503);
    });
    addTearDown(client.close);

    final first = _ReminderDelivery();
    await tester.pumpWidget(ApehApp(client: client, notifications: first));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Напоминания о смене карт'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ranked'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mixtape'));
    await tester.enterText(find.byType(TextFormField), '7');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(first.requestedPermission, isTrue);
    expect(first.plan.map((item) => item.title).toSet(), {
      'Apeh · Ranked',
      'Apeh · Mixtape',
    });
    expect(first.plan, hasLength(4));
    for (final item in first.plan) {
      expect(item.changeAt.difference(item.fireAt), const Duration(minutes: 7));
    }
    expect(first.plan.any((item) => item.body.contains('E-District')), isTrue);
    body = body.replaceFirst('E-District', 'World’s Edge');
    await tester.tap(find.byTooltip('Обновить карты'));
    await tester.pumpAndSettle();
    expect(first.plan.any((item) => item.body.contains('E-District')), isFalse);
    expect(
      first.plan.any((item) => item.body.contains('World’s Edge')),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());

    online = false;
    final restored = _ReminderDelivery();
    await tester.pumpWidget(ApehApp(client: client, notifications: restored));
    await tester.pumpAndSettle();
    expect(restored.plan, first.plan);
    expect(restored.requestedPermission, isFalse);

    await tester.tap(find.byTooltip('Напоминания о смене карт'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ranked'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mixtape'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(restored.plan, isEmpty);
    expect((await RotationStorage().readReminders())?.enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Выбранный пояс меняет время карт и сохраняется офлайн', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now().toUtc();
    final expected = now.add(const Duration(hours: 10));
    final hour = expected.hour.toString().padLeft(2, '0');
    final minute = expected.minute.toString().padLeft(2, '0');
    final tokyoStart = find.textContaining(
      RegExp(
        r'^с (?:\d{2}\.\d{2} в )?'
        '$hour:$minute'
        r'$',
      ),
    );
    var requests = 0;
    var online = true;
    final client = MockClient((_) async {
      requests++;
      return online
          ? http.Response(
              rotationPageFixture(now),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            )
          : http.Response('', 503);
    });
    addTearDown(client.close);

    await tester.pumpWidget(ApehApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Часовой пояс'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Токио');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Токио'));
    await tester.pumpAndSettle();
    expect(tokyoStart, findsOneWidget);
    expect(await RotationStorage().readTimeZone(), 'Asia/Tokyo');
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());

    online = false;
    await tester.pumpWidget(ApehApp(client: client));
    await tester.pumpAndSettle();
    expect(find.text('Токио'), findsOneWidget);
    expect(tokyoStart, findsOneWidget);
    expect(find.textContaining('Сохранённое расписание'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Ключ имеет приоритет, при отказе API работает сайт и кеш', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1050, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = RotationStorage();
    await storage.saveKey('test-only');
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.host);
      if (request.url.host == 'api.apexlegendsstatus.com') {
        expect(request.headers['authorization'], 'test-only');
        return http.Response('', 403);
      }
      expect(request.headers['authorization'], isNull);
      return _publicResponse();
    });
    addTearDown(client.close);
    await tester.pumpWidget(ApehApp(client: client));
    await tester.pumpAndSettle();
    expect(requests, ['api.apexlegendsstatus.com', 'apexlegendsstatus.com']);
    expect(
      find.textContaining('Используется публичное расписание'),
      findsOneWidget,
    );
    expect(
      (await storage.readSnapshot())?.playlists.keys,
      unorderedEquals(Playlist.values),
    );

    await tester.tap(find.byTooltip('Настроить ключ API'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить ключ'));
    await tester.pumpAndSettle();
    expect(await storage.readKey(), isNull);
    expect(requests.last, 'apexlegendsstatus.com');
    expect(requests.length, 3);
    await tester.pumpWidget(const SizedBox.shrink());

    final offline = MockClient((_) async => http.Response('', 503));
    addTearDown(offline.close);
    await tester.pumpWidget(ApehApp(client: offline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сохранённое расписание'), findsOneWidget);
    expect(find.text('Monument'), findsOneWidget);
    expect(find.text('Olympus'), findsOneWidget);
    expect(find.textContaining('До смены 20 д '), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Настройки интерфейса сохраняются, версия проверяется на GitHub',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1150, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final platform = tester.binding.platformDispatcher;
      platform.localeTestValue = const Locale('en');
      platform.platformBrightnessTestValue = Brightness.dark;
      addTearDown(platform.clearLocaleTestValue);
      addTearDown(platform.clearPlatformBrightnessTestValue);
      PackageInfo.setMockInitialValues(
        appName: 'Apeh',
        packageName: 'apeh',
        version: '1.0.1',
        buildNumber: '2',
        buildSignature: '',
      );
      var releaseChecks = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          releaseChecks++;
          expect(request.url.path, '/repos/Hecatoncheir/Apeh/releases/latest');
          return http.Response(
            '{"draft":false,"prerelease":false,"tag_name":"v1.0.2"}',
            200,
          );
        }
        return _publicResponse();
      });
      addTearDown(client.close);

      Future<void> choose<T>(String option) async {
        await tester.tap(find.byType(DropdownButton<T>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();
      final settings = find.text('Настройки');
      expect(tester.getBottomLeft(settings).dy, greaterThan(780));
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.text('Установленная версия 1.0.1'), findsOneWidget);
      expect(releaseChecks, 0);
      await choose<AppLanguage>('Английский');
      expect(find.text('Appearance'), findsOneWidget);
      await choose<ThemeMode>('Light');
      await choose<int>('125 %');
      final appearance = tester.element(find.text('Appearance'));
      expect(Theme.of(appearance).brightness, Brightness.light);
      expect(MediaQuery.sizeOf(appearance).width, 920);
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(releaseChecks, 1);
      expect(find.text('Latest version 1.0.2'), findsOneWidget);
      expect(find.text('Open release page'), findsOneWidget);

      await choose<ThemeMode>('Dark');
      expect(
        Theme.of(tester.element(find.text('Appearance'))).brightness,
        Brightness.dark,
      );
      await choose<ThemeMode>('Automatic');
      await choose<AppLanguage>('Automatic');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ApehApp(client: client));
      await tester.pumpAndSettle();
      expect(find.text('Map rotation'), findsOneWidget);
      expect(find.textContaining('Time left'), findsWidgets);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final restored = tester.element(find.text('Appearance'));
      expect(Theme.of(restored).brightness, Brightness.dark);
      expect(MediaQuery.sizeOf(restored).width, 920);
      expect(find.text('Automatic'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ReminderDelivery implements RotationNotifications {
  List<MapReminder> plan = [];
  bool requestedPermission = false;

  @override
  Future<String?> sync(
    List<MapReminder> plan, {
    required bool enabled,
    required bool requestPermission,
  }) async {
    this.plan = plan;
    requestedPermission = requestedPermission || requestPermission;
    return null;
  }

  @override
  void dispose() {}
}

http.Response _publicResponse() => http.Response(
  rotationPageFixture(DateTime.now()),
  200,
  headers: {'content-type': 'text/html; charset=utf-8'},
);
