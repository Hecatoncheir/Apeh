import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog_state.dart';
import 'legend_board.dart';
import 'legend_repository.dart';

class LegendsState {
  const LegendsState({
    this.rank = LegendRank.all,
    this.boards = const {},
    this.selectedName,
  });

  final LegendRank rank;
  final Map<LegendRank, CatalogState<LegendBoard>> boards;
  final String? selectedName;

  CatalogState<LegendBoard> boardFor(LegendRank rank) =>
      boards[rank] ?? const CatalogState();

  CatalogState<LegendBoard> get source => boardFor(rank);

  LegendPick? get selection {
    final picks = source.data?.picks ?? const <LegendPick>[];
    return picks.where((pick) => pick.name == selectedName).firstOrNull ??
        picks.firstOrNull;
  }

  LegendsState copyWith({
    LegendRank? rank,
    Map<LegendRank, CatalogState<LegendBoard>>? boards,
    String? selectedName,
  }) => LegendsState(
    rank: rank ?? this.rank,
    boards: boards ?? this.boards,
    selectedName: selectedName ?? this.selectedName,
  );
}

class LegendsCubit extends Cubit<LegendsState> {
  LegendsCubit(this._repository) : super(const LegendsState()) {
    refreshIfNeeded();
  }

  final LegendRepository _repository;

  void selectRank(LegendRank rank) {
    if (state.rank == rank) return;
    emit(state.copyWith(rank: rank));
    refreshIfNeeded();
  }

  void refreshIfNeeded() {
    final source = state.source;
    final board = source.data;
    if (board == null ||
        source.cached ||
        DateTime.now().difference(board.fetchedAt) >
            const Duration(minutes: 10)) {
      unawaited(refresh());
    }
  }

  void selectLegend(String name) => emit(state.copyWith(selectedName: name));

  Future<void> refresh() async {
    final rank = state.rank;
    final source = state.source;
    if (isClosed || source.loading) return;
    _show(rank, source.start());
    if (source.data == null) await _readCache(rank);
    if (isClosed) return;
    try {
      final snapshot = await _repository.fetch(
        rank,
        previous: state.boardFor(rank).data,
      );
      if (isClosed) return;
      await _saveCache(rank, snapshot);
      _show(rank, CatalogState.loaded(snapshot));
    } on Exception {
      _show(rank, state.boardFor(rank).fail());
    }
  }

  Future<void> _readCache(LegendRank rank) async {
    try {
      final board = await _repository.read(rank);
      if (board != null) _show(rank, CatalogState.restored(board));
    } on Exception {
      // При повреждении копии приложение попробует загрузить статистику.
    }
  }

  Future<void> _saveCache(LegendRank rank, LegendBoard snapshot) async {
    try {
      await _repository.save(rank, snapshot);
    } on Exception {
      // Статистика доступна в текущем сеансе.
    }
  }

  void _show(LegendRank rank, CatalogState<LegendBoard> source) {
    if (isClosed) return;
    emit(
      state.copyWith(boards: Map.unmodifiable({...state.boards, rank: source})),
    );
  }
}
