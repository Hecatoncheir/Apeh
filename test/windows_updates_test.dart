import 'dart:convert';

import 'package:apeh/updates/windows_release.dart';
import 'package:apeh/updates/windows_update_download.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url =
    'https://github.com/Hecatoncheir/Apeh/releases/download/v1.10.0/Apeh-Setup-x64.exe';
final _content = utf8.encode('Установщик из выпуска');

http.Response _release({String url = _url}) => http.Response(
  jsonEncode({
    'tag_name': 'v1.10.0',
    'draft': false,
    'prerelease': false,
    'assets': [
      {
        'name': windowsInstallerName,
        'state': 'uploaded',
        'browser_download_url': url,
        'size': _content.length,
        'digest': 'sha256:${sha256.convert(_content)}',
      },
    ],
  }),
  200,
);

void main() {
  test('Сравнивает номера версий и принимает установщик Apeh', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      expect(request.headers['authorization'], isNull);
      return _release();
    });
    addTearDown(client.close);
    expect(await checkWindowsRelease(client, '1.10.0'), isNull);
    expect(await checkWindowsRelease(client, '1.11.0'), isNull);
    final release = await checkWindowsRelease(client, '1.9.0');
    expect(release?.url, Uri.parse(_url));
    expect(release?.version.toString(), '1.10.0');
  });

  test('Отбрасывает установщик из другого репозитория', () async {
    final client = MockClient(
      (_) async => _release(url: _url.replaceFirst('/Apeh/', '/Other/')),
    );
    addTearDown(client.close);
    await expectLater(
      checkWindowsRelease(client, '1.0.0'),
      throwsA(isA<UpdateException>()),
    );
  });

  test('Скачивает установщик и отклоняет подмену того же размера', () async {
    List<int> contents = _content;
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com') return _release();
      expect(request.url, Uri.parse(_url));
      return http.Response.bytes(contents, 200);
    });
    addTearDown(client.close);
    final release = (await checkWindowsRelease(client, '1.0.0'))!;
    final installer = await downloadWindowsInstaller(client, release);
    addTearDown(() => removeWindowsInstaller(installer));
    expect(await installer.readAsBytes(), _content);
    contents = [..._content]..[0] ^= 1;
    await expectLater(
      downloadWindowsInstaller(client, release),
      throwsA(isA<UpdateException>()),
    );
  });
}
