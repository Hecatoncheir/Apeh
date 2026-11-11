import 'dart:async';

import 'package:flutter/foundation.dart';

import 'legend_board.dart';
import 'legend_repository.dart';

class LegendsViewModel extends ChangeNotifier {
  LegendsViewModel(this._repository) {
    unawaited(refresh());
  }

  final LegendRepository _repository;
  final _boards = <LegendRank, LegendBoard>{};
  final _pending = <LegendRank>{};
  final _cached = <LegendRank>{};
  final _failed = <LegendRank>{};
  LegendRank _rank = LegendRank.all;
  String? _selectedName;
  bool _disposed = false;

  LegendRank get rank => _rank;
  LegendBoard? get board => _boards[_rank];
  bool get loading => _pending.contains(_rank);
  bool get failed => _failed.contains(_rank);
  bool get fromCache => _cached.contains(_rank);

  LegendPick? get selection {
    final picks = board?.picks ?? const <LegendPick>[];
    return picks.where((pick) => pick.name == _selectedName).firstOrNull ??
        picks.firstOrNull;
  }

  void selectRank(LegendRank rank) {
    if (_rank == rank) return;
    _rank = rank;
    refreshIfNeeded();
    _notify();
  }

  void refreshIfNeeded() {
    final snapshot = board;
    if (snapshot == null ||
        fromCache ||
        DateTime.now().difference(snapshot.fetchedAt) >
            const Duration(minutes: 10)) {
      unawaited(refresh());
    }
  }

  void selectLegend(String name) {
    _selectedName = name;
    _notify();
  }

  Future<void> refresh() async {
    final rank = _rank;
    if (!_pending.add(rank)) return;
    _failed.remove(rank);
    _notify();
    if (!_boards.containsKey(rank)) await _readCache(rank);
    if (_disposed) return;
    try {
      final snapshot = await _repository.fetch(rank, previous: _boards[rank]);
      if (_disposed) return;
      _boards[rank] = snapshot;
      _cached.remove(rank);
      await _saveCache(rank, snapshot);
    } on Exception {
      _failed.add(rank);
      if (_boards.containsKey(rank)) _cached.add(rank);
    } finally {
      _pending.remove(rank);
      _notify();
    }
  }

  Future<void> _readCache(LegendRank rank) async {
    try {
      final snapshot = await _repository.read(rank);
      if (snapshot == null || _disposed) return;
      _boards[rank] = snapshot;
      _cached.add(rank);
      _notify();
    } on Exception {
      // Повреждённая копия не мешает обновлению.
    }
  }

  Future<void> _saveCache(LegendRank rank, LegendBoard snapshot) async {
    try {
      await _repository.save(rank, snapshot);
    } on Exception {
      // Данные остаются доступны до закрытия приложения.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
