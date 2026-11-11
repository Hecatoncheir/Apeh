import 'dart:async';

import 'package:flutter/foundation.dart';

import 'build_guides.dart';
import 'guide_repository.dart';
import 'upgrade_repository.dart';

enum GuideUpdateStatus { checking, current, updated, unavailable }

class BuildsViewModel extends ChangeNotifier {
  BuildsViewModel(this._repository, this._guides, {required this.online}) {
    unawaited(refreshGuides());
    if (online) unawaited(refresh());
  }

  final UpgradeRepository _repository;
  final GuideRepository _guides;
  final bool online;
  final _catalogs = <String, UpgradeCatalog>{};
  final _loading = <String>{};
  final _cached = <String>{};
  final _failed = <String>{};
  bool _disposed = false;
  BuildRange _range = BuildRange.medium;
  String _legendId = 'lifeline';
  GuideEdition? _edition;
  GuideUpdateStatus? _guideStatus;

  BuildRange get range => _range;
  Iterable<WeaponPair> get pairs =>
      _edition?.weaponPairs.where((pair) => pair.range == _range) ?? const [];
  List<BuildLegend> get legends => _edition?.legends ?? buildLegends;
  BuildLegend get legend =>
      _edition?.entries[_legendId]?.legend ??
      buildLegends.firstWhere((legend) => legend.id == _legendId);
  UpgradeCatalog? get catalog => _catalogs[_legendId];
  bool get loading => _loading.contains(_legendId);
  bool get cached => _cached.contains(_legendId);
  bool get failed => _failed.contains(_legendId);
  LegendGuide? get guide => _edition?.entries[_legendId]?.guide;
  GuideEdition? get edition => _edition;
  GuideUpdateStatus? get guideStatus => _guideStatus;

  void selectRange(BuildRange range) {
    _range = range;
    _notify();
  }

  void selectLegend(BuildLegend legend) {
    if (_legendId == legend.id) return;
    _legendId = legend.id;
    _notify();
    if (online && (catalog == null || cached)) unawaited(refresh());
  }

  Future<void> refreshGuides() async {
    if (_disposed || _guideStatus == GuideUpdateStatus.checking) return;
    _guideStatus = GuideUpdateStatus.checking;
    _notify();
    try {
      final current = _edition ?? await _loadGuides();
      if (_disposed) return;
      _edition = current;
      _notify();
      final update = await _guides.update(current);
      if (_disposed) return;
      _edition = update ?? current;
      _guideStatus = update == null
          ? GuideUpdateStatus.current
          : GuideUpdateStatus.updated;
    } on Exception {
      _guideStatus = GuideUpdateStatus.unavailable;
    } finally {
      _notify();
    }
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
    final legend = this.legend;
    final id = legend.id;
    if (!online || _disposed || !_loading.add(id)) return;
    _failed.remove(id);
    _notify();
    if (!_catalogs.containsKey(id)) await _readCache(legend);
    if (_disposed) return;
    try {
      final catalog = await _repository.fetch(legend);
      if (_disposed) return;
      _catalogs[id] = catalog;
      _cached.remove(id);
      await _saveCache(legend, catalog);
    } on Exception {
      _failed.add(id);
      if (_catalogs.containsKey(id)) _cached.add(id);
    } finally {
      _loading.remove(id);
      _notify();
    }
  }

  Future<void> _readCache(BuildLegend legend) async {
    try {
      final catalog = await _repository.read(legend);
      if (catalog == null || _disposed) return;
      _catalogs[legend.id] = catalog;
      _cached.add(legend.id);
      _notify();
    } on Exception {
      // При повреждении копии приложение попробует загрузить страницу.
    }
  }

  Future<void> _saveCache(BuildLegend legend, UpgradeCatalog catalog) async {
    try {
      await _repository.save(legend, catalog);
    } on Exception {
      // Данные остаются доступны в текущем сеансе.
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
