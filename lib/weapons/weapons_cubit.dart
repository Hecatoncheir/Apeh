import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog_state.dart';
import 'weapon.dart';
import 'weapon_repository.dart';

class WeaponsState {
  const WeaponsState({
    this.source = const CatalogState(),
    this.armor = Armor.purple,
    this.extended = false,
    this.first = 'r-301',
    this.second = 'flatline',
  });

  final CatalogState<WeaponCatalog> source;
  final Armor armor;
  final bool extended;
  final String first;
  final String second;

  Weapon? _find(String id) =>
      source.data?.weapons.where((weapon) => weapon.id == id).firstOrNull;

  bool get selectionUnavailable =>
      source.data != null && (_find(first) == null || _find(second) == null);

  Weapon selected({required bool left}) =>
      _find(left ? first : second) ?? source.data!.weapons[left ? 0 : 1];

  WeaponsState copyWith({
    CatalogState<WeaponCatalog>? source,
    Armor? armor,
    bool? extended,
    String? first,
    String? second,
  }) => WeaponsState(
    source: source ?? this.source,
    armor: armor ?? this.armor,
    extended: extended ?? this.extended,
    first: first ?? this.first,
    second: second ?? this.second,
  );
}

class WeaponsCubit extends Cubit<WeaponsState> {
  WeaponsCubit(this._repository) : super(const WeaponsState()) {
    unawaited(refresh());
  }

  final WeaponRepository _repository;

  void selectWeapon(String id, {required bool left}) =>
      emit(left ? state.copyWith(first: id) : state.copyWith(second: id));

  void selectPair(String first, String second) =>
      emit(state.copyWith(first: first, second: second));

  void selectArmor(Armor armor) => emit(state.copyWith(armor: armor));

  void selectMagazine(bool extended) =>
      emit(state.copyWith(extended: extended));

  Future<void> refresh() async {
    if (isClosed || state.source.loading) return;
    _show(state.source.start());
    if (state.source.data == null) await _readCache();
    if (isClosed) return;
    try {
      final catalog = await _repository.fetch();
      if (isClosed) return;
      final previous = state.source.data;
      if (previous != null && catalog.patch.isBefore(previous.patch)) {
        _show(state.source.fail());
        return;
      }
      await _saveCache(catalog);
      _show(CatalogState.loaded(catalog));
    } on Exception {
      _show(state.source.fail());
    }
  }

  Future<void> _readCache() async {
    try {
      final catalog = await _repository.read();
      if (catalog != null) _show(CatalogState.restored(catalog));
    } on Exception {
      // При повреждении копии приложение попробует загрузить каталог.
    }
  }

  Future<void> _saveCache(WeaponCatalog catalog) async {
    try {
      await _repository.save(catalog);
    } on Exception {
      // Каталог доступен в текущем сеансе.
    }
  }

  void _show(CatalogState<WeaponCatalog> source) {
    if (!isClosed) emit(state.copyWith(source: source));
  }
}
