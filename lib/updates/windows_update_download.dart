import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'windows_release.dart';

Future<File> downloadWindowsInstaller(
  http.Client client,
  WindowsRelease release,
) async {
  final request = http.Request('GET', release.url);
  final response = await client
      .send(request)
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    await response.stream.listen(null).cancel();
    throw const UpdateException('Не удалось скачать установщик с GitHub.');
  }

  final folder = await Directory.systemTemp.createTemp('apeh-update-');
  final installer = File.fromUri(folder.uri.resolve(windowsInstallerName));
  try {
    final output = installer.openWrite();
    var received = 0;
    try {
      final chunks = response.stream.timeout(const Duration(seconds: 30)).map((
        chunk,
      ) {
        received += chunk.length;
        if (received > release.size) {
          throw const UpdateException(
            'Размер установщика отличается от указанного в выпуске.',
          );
        }
        return chunk;
      });
      await output.addStream(chunks);
    } finally {
      await output.close();
    }
    final digest = await sha256.bind(installer.openRead()).single;
    if (received != release.size || digest.toString() != release.digest) {
      throw const UpdateException(
        'Установщик не прошёл проверку контрольной суммы.',
      );
    }
    return installer;
  } catch (_) {
    await removeWindowsInstaller(installer);
    rethrow;
  }
}

Future<void> removeWindowsInstaller(File installer) async {
  try {
    if (await installer.exists()) await installer.delete();
    await installer.parent.delete();
  } on FileSystemException {
    // Временный файл может оставаться заблокированным системой.
  }
}
