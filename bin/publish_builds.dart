import 'dart:convert';
import 'dart:io';

import 'package:apeh/builds/guide_edition.dart';
import 'package:apeh/builds/guide_publication.dart';

const _gist = '04760e1240bdd49a7612d4ac0316665f';
const _fileName = 'legend-guides.json';
const _usage =
    'Использование: dart run bin/publish_builds.dart <файл> [--publish]';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--help') {
    stdout.writeln(_usage);
    return;
  }
  if (args.isEmpty ||
      args.first.startsWith('-') ||
      args.length > 2 ||
      (args.length == 2 && args.last != '--publish')) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  try {
    await _publish(File(args.first), publish: args.length == 2);
  } on FormatException catch (error) {
    stderr.writeln(
      error.message.isEmpty
          ? 'Некорректный формат рекомендаций.'
          : error.message,
    );
    exitCode = 65;
  } on Exception catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<void> _publish(File input, {required bool publish}) async {
  final candidate = await input.readAsString();
  final published = await _readPublished();
  final result = prepareGuideUpdate(published, candidate);
  if (result == null) {
    stdout.writeln('Подборки совпадают с опубликованным выпуском.');
    return;
  }
  final revision = GuideEdition.parse(result).revision;
  if (!publish) {
    stdout.writeln('Проверен выпуск № $revision.');
    return;
  }

  final directory = await Directory.systemTemp.createTemp('apeh-builds-');
  final file = File.fromUri(directory.uri.resolve(_fileName));
  try {
    await file.writeAsString(result);
    if ((await _readPublished()).trim() != published.trim()) {
      throw const FormatException(
        'В Gist появился другой выпуск. Скачайте его и повторите.',
      );
    }
    await _gh(['gist', 'edit', _gist, '--filename', _fileName, file.path]);
    final actual = await _readPublished();
    if (actual.trim() != result.trim()) {
      throw Exception('Публикация не подтверждена. Проверьте содержимое Gist.');
    }
    stdout.writeln('Опубликован выпуск № $revision.');
  } finally {
    if (await file.exists()) await file.delete();
    await directory.delete();
  }
}

Future<String> _readPublished() =>
    _gh(['gist', 'view', _gist, '--filename', _fileName, '--raw']);

Future<String> _gh(List<String> arguments) async {
  final result = await Process.run(
    'gh',
    arguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'gh',
      arguments,
      result.stderr as String,
      result.exitCode,
    );
  }
  return result.stdout as String;
}
