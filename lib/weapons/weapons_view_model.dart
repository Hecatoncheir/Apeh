import 'dart:async';

import 'package:flutter/foundation.dart';

import 'weapon.dart';
import 'weapon_repository.dart';

class WeaponsViewModel extends ChangeNotifier {
  WeaponsViewModel(this._repository) {
    unawaited(refresh());
  }

  final WeaponRepository _repository;
  WeaponCatalog? _catalog;
  bool _loading = false;
  bool _cached = false;
  bool _failed = false;
  bool _disposed = false;
  Armor _armor = Armor.purple;
  bool _extended = false;
  String _leftId = 'r-301';
  String _rightId = 'flatline';

  WeaponCatalog? get catalog => _catalog;
  bool get loading => _loading;
  bool get cached => _cached;
  bool get failed => _failed;
  Armor get armor => _armor;
  bool get extended => _extended;
  bool get selectionUnavailable {
    final weapons = _catalog?.weapons;
    if (weapons == null) return false;
    return !weapons.any((weapon) => weapon.id == _leftId) ||
        !weapons.any((weapon) => weapon.id == _rightId);
  }

  Weapon selected({required bool left}) {
    final weapons = _catalog!.weapons;
    final id = left ? _leftId : _rightId;
    return weapons.where((weapon) => weapon.id == id).firstOrNull ??
        weapons[left ? 0 : 1];
  }

  void selectWeapon(String id, {required bool left}) {
    if (left) {
      _leftId = id;
    } else {
      _rightId = id;
    }
    _notify();
  }

  void selectPair(String first, String second) {
    _leftId = first;
    _rightId = second;
    _notify();
  }

  void selectArmor(Armor armor) {
    _armor = armor;
    _notify();
  }

  void selectMagazine(bool extended) {
    _extended = extended;
    _notify();
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    _failed = false;
    _notify();
    if (_catalog == null) await _readCache();
    if (_disposed) return;
    try {
      final catalog = await _repository.fetch();
      if (_disposed) return;
      if (_catalog case final previous?
          when catalog.patch.isBefore(previous.patch)) {
        throw const FormatException();
      }
      _catalog = catalog;
      _cached = false;
      await _saveCache(catalog);
    } on Exception {
      _failed = true;
      _cached = _catalog != null;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _readCache() async {
    try {
      final catalog = await _repository.read();
      if (_disposed || catalog == null) return;
      _catalog = catalog;
      _cached = true;
      _notify();
    } on Exception {
      // Повреждённая копия не мешает обновлению.
    }
  }

  Future<void> _saveCache(WeaponCatalog catalog) async {
    try {
      await _repository.save(catalog);
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
