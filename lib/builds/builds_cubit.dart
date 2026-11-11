import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog_state.dart';
import 'build_guides.dart';
import 'guide_repository.dart';
import 'upgrade_repository.dart';

enum GuideUpdateStatus { checking, current, updated, unavailable }

class BuildsState {
  const BuildsState({
    required this.online,
    this.range = BuildRange.medium,
    this.legendId = 'lifeline',
    this.catalogs = const {},
    this.edition,
    this.guideStatus,
  });

  final bool online;
  final BuildRange range;
  final String legendId;
  final Map<String, CatalogState<UpgradeCatalog>> catalogs;
  final GuideEdition? edition;
  final GuideUpdateStatus? guideStatus;

  Iterable<WeaponPair> get pairs =>
      edition?.weaponPairs.where((pair) => pair.range == range) ?? const [];
  List<BuildLegend> get legends => edition?.legends ?? buildLegends;
  BuildLegend get legend =>
      edition?.entries[legendId]?.legend ??
      buildLegends.firstWhere((legend) => legend.id == legendId);
  LegendGuide? get guide => edition?.entries[legendId]?.guide;
  CatalogState<UpgradeCatalog> get source => catalogFor(legendId);

  CatalogState<UpgradeCatalog> catalogFor(String id) =>
      catalogs[id] ?? const CatalogState();

  BuildsState copyWith({
    BuildRange? range,
    String? legendId,
    Map<String, CatalogState<UpgradeCatalog>>? catalogs,
    GuideEdition? edition,
    GuideUpdateStatus? guideStatus,
  }) => BuildsState(
    online: online,
    range: range ?? this.range,
    legendId: legendId ?? this.legendId,
    catalogs: catalogs ?? this.catalogs,
    edition: edition ?? this.edition,
    guideStatus: guideStatus ?? this.guideStatus,
  );
}

class BuildsCubit extends Cubit<BuildsState> {
  BuildsCubit(this._repository, this._guides, {required bool online})
    : super(BuildsState(online: online)) {
    unawaited(refreshGuides());
    if (online) unawaited(refresh());
  }

  final UpgradeRepository _repository;
  final GuideRepository _guides;

  void selectRange(BuildRange range) => emit(state.copyWith(range: range));

  void selectLegend(BuildLegend legend) {
    if (state.legendId == legend.id) return;
    emit(state.copyWith(legendId: legend.id));
    final source = state.source;
    if (state.online && (source.data == null || source.cached)) {
      unawaited(refresh());
    }
  }

  Future<void> refreshGuides() async {
    if (isClosed || state.guideStatus == GuideUpdateStatus.checking) return;
    _showGuides(GuideUpdateStatus.checking);
    try {
      final current = state.edition ?? await _loadGuides();
      if (isClosed) return;
      _showGuides(GuideUpdateStatus.checking, edition: current);
      final update = await _guides.update(current);
      _showGuides(
        update == null ? GuideUpdateStatus.current : GuideUpdateStatus.updated,
        edition: update,
      );
    } on Exception {
      _showGuides(GuideUpdateStatus.unavailable);
    }
  }

  void _showGuides(GuideUpdateStatus status, {GuideEdition? edition}) {
    if (!isClosed) emit(state.copyWith(edition: edition, guideStatus: status));
  }

  Future<GuideEdition> _loadGuides() async {
    final bundled = await _guides.bundled();
    try {
      final cached = await _guides.read();
      if (cached != null && cached.revision > bundled.revision) return cached;
    } on Exception {
      // При повреждении копии используем выпуск из приложения.
    }
    return bundled;
  }

  Future<void> refresh() async {
    final source = state.source;
    if (!state.online || isClosed || source.loading) return;
    final legend = state.legend;
    final id = legend.id;
    _showCatalog(id, source.start());
    if (source.data == null) await _readCache(legend);
    if (isClosed) return;
    try {
      final catalog = await _repository.fetch(legend);
      if (isClosed) return;
      await _saveCache(legend, catalog);
      _showCatalog(id, CatalogState.loaded(catalog));
    } on Exception {
      _showCatalog(id, state.catalogFor(id).fail());
    }
  }

  Future<void> _readCache(BuildLegend legend) async {
    try {
      final catalog = await _repository.read(legend);
      if (catalog != null) {
        _showCatalog(legend.id, CatalogState.restored(catalog));
      }
    } on Exception {
      // При повреждении копии приложение попробует загрузить страницу.
    }
  }

  Future<void> _saveCache(BuildLegend legend, UpgradeCatalog catalog) async {
    try {
      await _repository.save(legend, catalog);
    } on Exception {
      // Справочник доступен в текущем сеансе.
    }
  }

  void _showCatalog(String id, CatalogState<UpgradeCatalog> source) {
    if (isClosed) return;
    emit(
      state.copyWith(
        catalogs: Map.unmodifiable({...state.catalogs, id: source}),
      ),
    );
  }
}
