enum LegendRank {
  all('Все игроки', ''),
  unranked('Новичок / без ранга', 'Unranked'),
  bronze('Бронза', 'Bronze'),
  silver('Серебро', 'Silver'),
  gold('Золото', 'Gold'),
  platinum('Платина', 'Platinum'),
  diamond('Алмаз', 'Diamond'),
  masterPred('Мастер / Хищник', 'Masterpred');

  const LegendRank(this.label, this.path);

  final String label;
  final String path;
}

class LegendPick {
  const LegendPick(this.name, this.percent, this.portrait);

  final String name;
  final double percent;
  final Uri? portrait;
}

class PickPoint {
  const PickPoint(this.day, this.percent);

  final DateTime day;
  final double percent;
}

class LegendBoard {
  LegendBoard({
    required this.fetchedAt,
    required List<LegendPick> picks,
    required Map<String, List<PickPoint>> history,
  }) : picks = List.unmodifiable(picks),
       history = Map.unmodifiable(history);

  final DateTime fetchedAt;
  final List<LegendPick> picks;
  final Map<String, List<PickPoint>> history;
}
