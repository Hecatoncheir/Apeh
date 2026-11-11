import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'weapon.dart';

final weaponCatalogUri = Uri.https('apex-legends.ttkdb.com', '/en/compare');

class WeaponCatalog {
  WeaponCatalog(this.season, this.patch, List<Weapon> weapons)
    : weapons = List.unmodifiable(weapons);

  final String season;
  final DateTime patch;
  final List<Weapon> weapons;
}

class WeaponRepository {
  WeaponRepository(this._client);

  final http.Client _client;
  static const _cacheKey = 'weapons.catalog.v1';

  Future<WeaponCatalog> fetch() async {
    final response = await _client
        .get(weaponCatalogUri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw const FormatException();
    return compute(parseWeaponCatalog, utf8.decode(response.bodyBytes));
  }

  Future<WeaponCatalog?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_cacheKey);
    if (encoded == null) return null;
    final Object? json = jsonDecode(encoded);
    if (json case {
      'season': final String season,
      'patch': final String patch,
      'weapons': final List<Object?> entries,
    }) {
      return _catalog(season, patch, entries);
    }
    return null;
  }

  Future<void> save(WeaponCatalog catalog) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cacheKey,
      jsonEncode({
        'season': catalog.season,
        'patch': catalog.patch.toIso8601String(),
        'weapons': [for (final weapon in catalog.weapons) weapon.toJson()],
      }),
    );
  }
}

WeaponCatalog parseWeaponCatalog(String page) {
  final document = html.parse(page);
  final season = document
      .querySelector('.data-basis span')
      ?.text
      .split('·')
      .last
      .trim();
  final patch = document
      .querySelector('.data-basis time')
      ?.attributes['datetime'];
  if (season == null || patch == null) throw const FormatException();

  return _catalog(season, patch, _weaponEntries(document));
}

List<Object?> _weaponEntries(Document document) {
  final text = _pagePayload(document);
  const marker = '"weapons":[';
  final index = text.indexOf(marker);
  if (index == -1) throw const FormatException();
  final Object? entries = jsonDecode(
    _jsonArray(text, index + marker.length - 1),
  );
  if (entries is! List<Object?>) throw const FormatException();
  return entries;
}

String _pagePayload(Document document) {
  // Страница передаёт список в JSON-строках. Сценарии сайта не исполняются.
  const prefix = 'self.__next_f.push([1,';
  final payload = StringBuffer();
  for (final script in document.querySelectorAll('script')) {
    final code = script.text.trim();
    if (!code.startsWith(prefix) || !code.endsWith('])')) continue;
    final Object? chunk = jsonDecode(
      code.substring(prefix.length, code.length - 2),
    );
    if (chunk is String) payload.write(chunk);
  }
  return payload.toString();
}

WeaponCatalog _catalog(String season, String patch, List<Object?> entries) {
  final date = DateTime.tryParse(patch);
  if (season.isEmpty || date == null) throw const FormatException();
  final weapons = <String, Weapon>{};
  for (final item in entries) {
    if (item is! Map<String, Object?>) continue;
    final weapon = Weapon.fromJson(item);
    weapons[weapon.id] = weapon;
  }
  if (weapons.length < 2) throw const FormatException();
  return WeaponCatalog(
    season,
    date,
    weapons.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
}

String _jsonArray(String text, int start) {
  var depth = 0;
  for (var index = start; index < text.length; index++) {
    switch (text[index]) {
      case '"':
        index = _endOfString(text, index + 1);
      case '[':
        depth++;
      case ']':
        if (--depth == 0) return text.substring(start, index + 1);
    }
  }
  throw const FormatException();
}

int _endOfString(String text, int start) {
  for (var index = start; index < text.length; index++) {
    switch (text[index]) {
      case '"':
        return index;
      case r'\':
        index++;
    }
  }
  throw const FormatException();
}
