import 'package:flutter/material.dart';

import '../l10n/localization.dart';
import 'rotation.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_ui_text.dart';

class FavoriteMapPicker extends StatefulWidget {
  const FavoriteMapPicker({
    super.key,
    required this.availableMaps,
    required this.favorites,
    required this.onChanged,
  });

  final Iterable<String> availableMaps;
  final List<FavoriteMap> favorites;
  final ValueChanged<List<FavoriteMap>> onChanged;

  @override
  State<FavoriteMapPicker> createState() => _FavoriteMapPickerState();
}

class _FavoriteMapPickerState extends State<FavoriteMapPicker> {
  final _input = TextEditingController();
  late var _names = {
    for (final favorite in widget.favorites) favorite.key: favorite.name,
    for (final name in widget.availableMaps) mapKey(name): name,
  };
  late final _modes = {
    for (final favorite in widget.favorites)
      favorite.key: favorite.playlists.toSet(),
  };
  String? _expanded;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _addMap() {
    final name = _input.text.trim();
    final key = mapKey(name);
    if (key.isEmpty) return;
    setState(() {
      _names = {key: _names[key] ?? name, ..._names};
      _expanded = key;
    });
    _input.clear();
  }

  void _select(String key, Playlist mode, bool selected) {
    setState(() {
      final modes = _modes.putIfAbsent(key, () => {});
      if (selected) {
        modes.add(mode);
      } else {
        modes.remove(mode);
      }
    });
    widget.onChanged([
      for (final entry in _modes.entries)
        if (entry.value.isNotEmpty)
          FavoriteMap(_names[entry.key]!, entry.value),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(strings.favoriteMapHelp),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addMap(),
          decoration: InputDecoration(
            labelText: strings.favoriteMapName,
            suffixIcon: IconButton(
              tooltip: strings.addFavoriteMap,
              onPressed: _addMap,
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final MapEntry(:key, :value) in _names.entries)
          _mapTile(context, key, value),
      ],
    );
  }

  Widget _mapTile(BuildContext context, String key, String name) {
    final modes = _modes[key] ?? const <Playlist>{};
    return ExpansionTile(
      key: ValueKey((key, _expanded == key)),
      initiallyExpanded:
          _expanded == key || widget.favorites.any((map) => map.key == key),
      tilePadding: EdgeInsets.zero,
      title: Text(name),
      leading: Icon(modes.isEmpty ? Icons.star_border : Icons.star),
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final mode in Playlist.values)
              FilterChip(
                label: Text(playlistLabel(context, mode)),
                selected: modes.contains(mode),
                onSelected: (value) => _select(key, mode, value),
              ),
          ],
        ),
      ],
    );
  }
}
