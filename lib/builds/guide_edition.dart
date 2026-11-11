import 'dart:convert';

import 'build_guides.dart';
import 'patch_highlights.dart';

final _contentId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

typedef GuideEntry = ({BuildLegend legend, LegendGuide guide});

class GuideEdition {
  GuideEdition._(
    this.revision,
    this.patch,
    Map<String, GuideEntry> entries,
    List<WeaponPair> pairs,
    this.highlights,
  ) : entries = Map.unmodifiable(entries),
      weaponPairs = List.unmodifiable(pairs),
      legends = List.unmodifiable(
        entries.values.map((entry) => entry.legend).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ),
      );

  factory GuideEdition.parse(String json) {
    final data = jsonDecode(json);
    if (data
        case {
          'schema': 1,
          'revision': final int revision,
          'patch': final String patch,
          'legends': final Map<String, Object?> rows,
        }
        when revision > 0) {
      final entries = rows.map((id, row) => MapEntry(id, _parseEntry(id, row)));
      if (buildLegends.every((legend) => entries.containsKey(legend.id))) {
        final pairs = data['weaponPairs'];
        return GuideEdition._(
          revision,
          _text(patch),
          entries,
          revision == 1 && pairs == null ? const [] : _parseWeaponPairs(pairs),
          PatchHighlights.parse(data['patchHighlights']),
        );
      }
    }
    throw const FormatException();
  }

  final int revision;
  final String patch;
  final Map<String, GuideEntry> entries;
  final List<BuildLegend> legends;
  final List<WeaponPair> weaponPairs;
  final PatchHighlights? highlights;
}

List<WeaponPair> _parseWeaponPairs(Object? value) {
  if (value is! List<Object?>) throw const FormatException();
  final pairs = value.map(_parseWeaponPair).toList();
  final ranges = <BuildRange>{};
  final seen = <(BuildRange, String, String)>{};
  for (final pair in pairs) {
    ranges.add(pair.range);
    if (seen.contains((pair.range, pair.second, pair.first)) ||
        !seen.add((pair.range, pair.first, pair.second))) {
      throw const FormatException();
    }
  }
  if (!ranges.containsAll(BuildRange.values)) throw const FormatException();
  return pairs;
}

WeaponPair _parseWeaponPair(Object? row) {
  if (row
      case {
        'range': final String distance,
        'first': final String first,
        'second': final String second,
        'title': final String title,
        'reason': final String reason,
      }
      when first != second &&
          _contentId.hasMatch(first) &&
          _contentId.hasMatch(second)) {
    final range = BuildRange.values.asNameMap()[distance];
    if (range != null) {
      return WeaponPair(range, first, second, _text(title), _text(reason));
    }
  }
  throw const FormatException();
}

GuideEntry _parseEntry(String id, Object? row) {
  if (!_contentId.hasMatch(id)) throw const FormatException();
  if (row
      case {
        'name': final String name,
        'styles': [final String first, final String second],
        'level2': final Object? levelTwo,
        'level3': final Object? levelThree,
      }
      when _text(first) != _text(second)) {
    final legacy = switch (row['catalogLegacyNames']) {
      null => const <String>{},
      final List<Object?> names => Set<String>.unmodifiable(names.map(_text)),
      _ => throw const FormatException(),
    };
    final guide = LegendGuide(
      _text(first),
      _text(second),
      _parseLevel(2, levelTwo),
      _parseLevel(3, levelThree),
      catalogLegacyNames: legacy,
    );
    if (guide.upgradeNames.toSet().length == 4) {
      return (legend: BuildLegend(id, _text(name)), guide: guide);
    }
  }
  throw const FormatException();
}

UpgradeLevel _parseLevel(int level, Object? value) => switch (value) {
  [final Object? first, final Object? second] => UpgradeLevel(
    level,
    _parseChoice(first),
    _parseChoice(second),
  ),
  _ => throw const FormatException(),
};

UpgradeChoice _parseChoice(Object? value) => switch (value) {
  {'name': final Object? name, 'reason': final Object? reason} => UpgradeChoice(
    _text(name),
    _text(reason),
  ),
  _ => throw const FormatException(),
};

String _text(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException();
}
