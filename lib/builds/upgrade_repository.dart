import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'build_guides.dart';

Uri upgradeSource(BuildLegend legend) =>
    Uri.https('apex.source.gs', '/legends/${legend.id}/');

class LegendUpgrade {
  const LegendUpgrade(this.name, this.effect);

  final String name;
  final String effect;
}

class UpgradeCatalog {
  UpgradeCatalog(this.published, List<LegendUpgrade> upgrades)
    : upgrades = List.unmodifiable(upgrades);

  final String published;
  final List<LegendUpgrade> upgrades;

  bool matches(LegendGuide guide) {
    final names = upgrades.map((upgrade) => upgrade.name).toSet();
    final expected = guide.upgradeNames.toSet();
    return names.containsAll(expected) &&
        names.difference(expected).every(guide.catalogLegacyNames.contains);
  }
}

class UpgradeRepository {
  UpgradeRepository(this._client);

  final http.Client _client;

  Future<UpgradeCatalog> fetch(BuildLegend legend) async {
    final response = await _client
        .get(upgradeSource(legend))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const FormatException();
    return compute(parseUpgradeCatalog, (
      utf8.decode(response.bodyBytes),
      legend.name,
    ));
  }

  String _key(BuildLegend legend) => 'builds.upgrades.v1.${legend.id}';

  Future<UpgradeCatalog?> read(BuildLegend legend) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key(legend));
    if (encoded == null) return null;
    final Object? data = jsonDecode(encoded);
    if (data case {
      'published': final String date,
      'upgrades': final List<Object?> rows,
    }) {
      final upgrades = [
        for (final row in rows)
          if (row case [final String name, final String effect])
            LegendUpgrade(name, effect),
      ];
      if (upgrades.isNotEmpty) return UpgradeCatalog(date, upgrades);
    }
    return null;
  }

  Future<void> save(BuildLegend legend, UpgradeCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(legend),
      jsonEncode({
        'published': catalog.published,
        'upgrades': [
          for (final upgrade in catalog.upgrades)
            [upgrade.name, upgrade.effect],
        ],
      }),
    );
  }
}

UpgradeCatalog parseUpgradeCatalog((String, String) input) {
  final (page, legend) = input;
  final document = html.parse(page);
  if (document.querySelector('main h1')?.text.trim() != legend) {
    throw const FormatException();
  }
  final section = document
      .querySelectorAll('main section')
      .where(
        (section) => section.querySelector('h2')?.text.trim() == 'Upgrades',
      )
      .firstOrNull;
  if (section == null) throw const FormatException();
  final upgrades = section
      .querySelectorAll('.slab')
      .map(_parseUpgrade)
      .nonNulls
      .toList();
  if (upgrades.isEmpty) throw const FormatException();
  final footer = document.querySelector('footer')?.text ?? '';
  final date = RegExp(r'updated\s+(\d{4}-\d{2}-\d{2})')
      .firstMatch(footer)
      ?.group(1);
  return UpgradeCatalog(date ?? '', upgrades);
}

LegendUpgrade? _parseUpgrade(Element card) {
  final name = card.querySelector('h3')?.text.trim() ?? '';
  final effect =
      card.querySelector('p')?.text.trim().replaceAll('%%', '%') ?? '';
  return name.isEmpty || effect.isEmpty ? null : LegendUpgrade(name, effect);
}
