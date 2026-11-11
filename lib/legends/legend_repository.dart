import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'legend_board.dart';

class LegendRepository {
  LegendRepository(this._client);

  static const _host = 'apexlegendsstatus.com';
  final http.Client _client;

  Future<LegendBoard> fetch(LegendRank rank, {LegendBoard? previous}) async {
    final suffix = rank.path.isEmpty ? '' : '/${rank.path}';
    final uri = Uri.https(_host, '/game-stats/legends-pick-rates$suffix');
    final historyFuture = _fetchHistory(rank);
    final picks = parsePicks(await _get(uri), uri);
    final fetchedAt = DateTime.now();
    final history = await historyFuture;
    return LegendBoard(
      fetchedAt: fetchedAt,
      picks: picks,
      history: history ?? previous?.history ?? const {},
    );
  }

  Future<Map<String, List<PickPoint>>?> _fetchHistory(LegendRank rank) async {
    final suffix = rank.path.isEmpty ? '' : '_${rank.path.toLowerCase()}';
    final uri = Uri.https(_host, '/lib/legendtrend$suffix.json');
    try {
      return parsePickHistory(await _get(uri));
    } on Exception {
      return null;
    }
  }

  Future<String> _get(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const FormatException('Apex Legends Status недоступен.');
    }
    return utf8.decode(response.bodyBytes);
  }

  String _cacheKey(LegendRank rank) => 'legends.board.v1.${rank.name}';

  Future<LegendBoard?> read(LegendRank rank) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_cacheKey(rank));
    if (encoded == null) return null;
    final Object? value = jsonDecode(encoded);
    if (value case {
      'fetchedAt': final String fetched,
      'picks': final List<Object?> picks,
      'history': final Map<String, Object?> history,
    }) {
      final date = DateTime.tryParse(fetched);
      if (date == null) return null;
      final restored = [
        for (final item in picks)
          if (item case [
            final String name,
            final num percent,
            final String? image,
          ])
            LegendPick(
              name,
              percent.toDouble(),
              image == null ? null : Uri.tryParse(image),
            ),
      ];
      if (restored.isEmpty) return null;
      return LegendBoard(
        fetchedAt: date,
        picks: restored,
        history: {
          for (final MapEntry(:key, :value) in history.entries)
            if (value is List<Object?>)
              key: [
                for (final point in value)
                  if (point case [final int epoch, final num percent])
                    PickPoint(
                      DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
                      percent.toDouble(),
                    ),
              ],
        },
      );
    }
    return null;
  }

  Future<void> save(LegendRank rank, LegendBoard board) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cacheKey(rank),
      jsonEncode({
        'fetchedAt': board.fetchedAt.toUtc().toIso8601String(),
        'picks': [
          for (final pick in board.picks)
            [pick.name, pick.percent, pick.portrait?.toString()],
        ],
        'history': {
          for (final MapEntry(:key, :value) in board.history.entries)
            key: [
              for (final point in value)
                [point.day.millisecondsSinceEpoch, point.percent],
            ],
        },
      }),
    );
  }
}

final _percentText = RegExp(r'^([0-9]+(?:[.,][0-9]+)?)\s*%$');

List<LegendPick> parsePicks(String body, Uri uri) {
  final picks = <String, LegendPick>{};
  final document = html.parse(body);
  for (final card in document.querySelectorAll('.legends-banner__item')) {
    final image = card.querySelector('img.legends-banner__image');
    final name = image?.attributes['alt']?.trim() ?? '';
    final content = card.querySelector('.legends-banner__content');
    if (name.isEmpty || content == null) continue;
    // Первое процентное значение — доля выбора. Следующее показывает изменение.
    final rate = _percentText.firstMatch(
      content.querySelector('span')?.text.trim() ?? '',
    );
    final percent = _percentage(rate?.group(1)?.replaceAll(',', '.'));
    if (percent == null) continue;
    final url =
        card.querySelector('source[type="image/webp"]')?.attributes['srcset'] ??
        image?.attributes['src'];
    final reference = url == null ? null : Uri.tryParse(url);
    final portrait = reference == null ? null : uri.resolveUri(reference);
    picks[name] = LegendPick(
      name,
      percent,
      portrait?.scheme == 'https' && portrait?.host == uri.host
          ? portrait
          : null,
    );
  }
  if (picks.isEmpty) throw const FormatException('Нет долей выбора.');
  return picks.values.toList()..sort((a, b) => b.percent.compareTo(a.percent));
}

Map<String, List<PickPoint>> parsePickHistory(String body) {
  final Object? decoded = jsonDecode(body);
  if (decoded is! List<Object?>) throw const FormatException();
  final series = <String, List<Object?>>{
    for (final item in decoded)
      if (item case {
        'name': final String name,
        'data': final List<Object?> values,
      })
        name: values,
  };
  final dates = series.remove('Date');
  if (dates == null || dates.isEmpty) throw const FormatException();
  final recentDates = <int, DateTime>{};
  final seenDays = <DateTime>{};
  final last = _day(dates.last);
  if (last == null) throw const FormatException();
  final first = last.subtract(const Duration(days: 29));
  for (var index = dates.length - 1; index >= 0; index--) {
    final day = _day(dates[index]);
    if (day == null) continue;
    if (day.isBefore(first)) break;
    if (seenDays.add(day)) recentDates[index] = day;
  }
  final indices = recentDates.keys.toList().reversed;
  final history = <String, List<PickPoint>>{
    for (final MapEntry(:key, :value) in series.entries)
      key: List.unmodifiable([
        for (final index in indices)
          if (index < value.length)
            if (_percentage(value[index]) case final percent?)
              PickPoint(recentDates[index]!, percent),
      ]),
  };
  if (!history.values.any((points) => points.isNotEmpty)) {
    throw const FormatException();
  }
  return history;
}

DateTime? _day(Object? value) =>
    value is String ? DateTime.tryParse('${value}T00:00:00Z') : null;

double? _percentage(Object? value) {
  final number = switch (value) {
    final num numeric => numeric.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
  return number != null && number >= 0 && number <= 100 ? number : null;
}
