import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BuildItem = ({String id, String name});

class SavedBuild {
  const SavedBuild({
    required this.id,
    required this.name,
    required this.legend,
    required this.first,
    required this.second,
    required this.levelTwo,
    required this.levelThree,
  });

  final String id;
  final String name;
  final BuildItem legend;
  final BuildItem first;
  final BuildItem second;
  final String levelTwo;
  final String levelThree;

  static SavedBuild parse(Object? row) {
    if (row case {
      'id': final String id,
      'name': final String name,
      'legend': final Object? legend,
      'first': final Object? first,
      'second': final Object? second,
      'levelTwo': final String levelTwo,
      'levelThree': final String levelThree,
    }) {
      return SavedBuild(
        id: id,
        name: name,
        legend: _item(legend),
        first: _item(first),
        second: _item(second),
        levelTwo: levelTwo,
        levelThree: levelThree,
      );
    }
    throw const FormatException();
  }

  static BuildItem _item(Object? row) {
    if (row case {'id': final String id, 'name': final String name}) {
      return (id: id, name: name);
    }
    throw const FormatException();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'legend': _itemJson(legend),
    'first': _itemJson(first),
    'second': _itemJson(second),
    'levelTwo': levelTwo,
    'levelThree': levelThree,
  };

  static Map<String, String> _itemJson(BuildItem item) => {
    'id': item.id,
    'name': item.name,
  };
}

typedef SavedBuildsState = ({List<SavedBuild>? items, bool busy});

class SavedBuildsCubit extends Cubit<SavedBuildsState> {
  SavedBuildsCubit() : super((items: null, busy: true)) {
    unawaited(_restore());
  }

  static const _key = 'builds.saved.v1';

  Future<void> _restore() async {
    List<SavedBuild>? items;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      final Object? data = value == null
          ? const <Object?>[]
          : jsonDecode(value);
      if (data is List<Object?>) {
        items = List.unmodifiable(data.map(SavedBuild.parse));
      }
    } on Exception {
      // При сбое чтения существующие записи сохраняются на диске.
    }
    if (!isClosed) emit((items: items, busy: false));
  }

  Future<bool> save(SavedBuild build) => _write((items) {
    final index = items.indexWhere((item) => item.id == build.id);
    if (index < 0) return [...items, build];
    return [...items]..[index] = build;
  });

  Future<bool> remove(SavedBuild build) =>
      _write((items) => items.where((item) => item.id != build.id).toList());

  Future<bool> _write(
    List<SavedBuild> Function(List<SavedBuild>) update,
  ) async {
    final items = state.items;
    if (state.busy || items == null || isClosed) return false;
    emit((items: items, busy: true));
    List<SavedBuild> next = items;
    try {
      final changed = update(items);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, jsonEncode(changed))) return false;
      next = List.unmodifiable(changed);
      return true;
    } on Exception {
      return false;
    } finally {
      if (!isClosed) emit((items: next, busy: false));
    }
  }
}
