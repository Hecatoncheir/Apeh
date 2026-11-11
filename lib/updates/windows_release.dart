import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

const _repository = 'Hecatoncheir/Apeh';
const releaseBuildVersion = String.fromEnvironment('APEH_VERSION');
const windowsInstallerName = 'Apeh-Setup-x64.exe';
final _latestRelease = Uri.https(
  'api.github.com',
  '/repos/$_repository/releases/latest',
);
final _stableTag = RegExp(r'^v(\d+\.\d+\.\d+)$');
final _sha256 = RegExp(r'^sha256:([a-f0-9]{64})$');
const _maxInstallerSize = 200 * 1024 * 1024;

class WindowsRelease {
  const WindowsRelease._(this.version, this.url, this.size, this.digest);

  final Version version;
  final Uri url;
  final int size;
  final String digest;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;
}

Future<WindowsRelease?> checkWindowsRelease(
  http.Client client,
  String current,
) async {
  final data = await _fetchLatestRelease(client);
  if (data == null) return null;
  if (data case {'assets': final List<Object?> assets}) {
    final tag = _releaseTag(data);
    final version = _versionFromTag(tag);
    if (version == null || version <= Version.parse(current)) return null;
    return _findInstaller(assets, tag, version);
  }
  throw _invalidRelease;
}

Future<Version?> checkPublishedVersion(http.Client client) async {
  final data = await _fetchLatestRelease(client);
  return data == null ? null : _versionFromTag(_releaseTag(data));
}

const _invalidRelease = UpdateException(
  'GitHub вернул неполные данные о выпуске.',
);

String _releaseTag(Object data) => switch (data) {
  {'draft': false, 'prerelease': false, 'tag_name': final String tag} => tag,
  _ => throw _invalidRelease,
};

Version? _versionFromTag(String tag) {
  final match = _stableTag.firstMatch(tag);
  return match == null ? null : Version.parse(match[1]!);
}

WindowsRelease _findInstaller(
  List<Object?> assets,
  String tag,
  Version version,
) {
  final expected = Uri.https(
    'github.com',
    '/$_repository/releases/download/$tag/$windowsInstallerName',
  );
  for (final asset in assets) {
    final release = _parseInstaller(asset, expected, version);
    if (release != null) return release;
  }
  throw const UpdateException(
    'В выпуске нет проверяемого установщика для Windows.',
  );
}

WindowsRelease? _parseInstaller(Object? asset, Uri expected, Version version) {
  if (asset
      case {
        'name': windowsInstallerName,
        'state': 'uploaded',
        'browser_download_url': final String url,
        'size': final int size,
        'digest': final String digest,
      }
      when url == expected.toString() &&
          size > 0 &&
          size <= _maxInstallerSize) {
    final hash = _sha256.firstMatch(digest);
    if (hash != null) {
      return WindowsRelease._(version, expected, size, hash[1]!);
    }
  }
  return null;
}

Future<Object?> _fetchLatestRelease(http.Client client) async {
  final response = await client
      .get(_latestRelease, headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 15));
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw const UpdateException('GitHub недоступен. Попробуйте позже.');
  }
  final data = jsonDecode(utf8.decode(response.bodyBytes));
  if (data == null) {
    throw _invalidRelease;
  }
  return data;
}
