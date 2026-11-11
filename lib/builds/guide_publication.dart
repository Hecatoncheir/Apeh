import 'dart:convert';

import 'guide_edition.dart';

String? prepareGuideUpdate(String publishedJson, String candidateJson) {
  final published = GuideEdition.parse(publishedJson);
  final candidate = GuideEdition.parse(candidateJson);
  if (candidate.revision != published.revision) {
    throw const FormatException('Подборка подготовлена для другого выпуска.');
  }
  if (!published.entries.keys.every(candidate.entries.containsKey)) {
    throw const FormatException(
      'Из подборки пропали ранее выпущенные легенды.',
    );
  }

  final before = jsonDecode(publishedJson) as Map<String, Object?>;
  final after = jsonDecode(candidateJson) as Map<String, Object?>;
  if (_content(before) == _content(after)) return null;
  after['revision'] = published.revision + 1;
  final result = const JsonEncoder.withIndent('  ').convert(after);
  GuideEdition.parse(result);
  return '$result\n';
}

String _content(Map<String, Object?> edition) => jsonEncode(
  _sorted([
    edition['legends'],
    edition['weaponPairs'],
    edition['patchHighlights'],
  ]),
);

Object? _sorted(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final key in map.keys.toList()..sort()) key: _sorted(map[key]),
  },
  final List<Object?> list => list.map(_sorted).toList(),
  _ => value,
};
