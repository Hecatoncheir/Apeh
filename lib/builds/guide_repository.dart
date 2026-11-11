import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'guide_edition.dart';

export 'guide_edition.dart';

const _asset = 'assets/legend-guides.json';
const _cacheKey = 'builds.guides.v1';
final _source = Uri.https(
  'gist.githubusercontent.com',
  '/Hecatoncheir/04760e1240bdd49a7612d4ac0316665f/raw/legend-guides.json',
);

class GuideRepository {
  GuideRepository(this._client);

  final http.Client _client;

  Future<GuideEdition> bundled() async =>
      GuideEdition.parse(await rootBundle.loadString(_asset));

  Future<GuideEdition?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheKey);
    return json == null ? null : GuideEdition.parse(json);
  }

  Future<GuideEdition?> update(GuideEdition current) async {
    final response = await _client
        .get(_source)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const FormatException();
    final json = utf8.decode(response.bodyBytes);
    final edition = GuideEdition.parse(json);
    if (edition.revision <= current.revision) return null;
    if (!current.entries.keys.every(edition.entries.containsKey)) {
      throw const FormatException();
    }
    final cachedJson = _keepHighlights(json, edition, current);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_cacheKey, cachedJson)) {
      throw const FormatException();
    }
    return cachedJson == json ? edition : GuideEdition.parse(cachedJson);
  }

  String _keepHighlights(String json, GuideEdition next, GuideEdition current) {
    final previous = current.highlights;
    if (next.highlights != null || previous == null) return json;
    final data = jsonDecode(json) as Map<String, Object?>;
    return jsonEncode({...data, 'patchHighlights': previous.toJson()});
  }
}
