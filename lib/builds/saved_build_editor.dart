import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/apeh_design.dart';
import '../l10n/localization.dart';
import '../weapons/weapon.dart';
import '../weapons/weapons_cubit.dart';
import 'build_guides.dart';
import 'guide_edition.dart';
import 'saved_builds.dart';

class SavedBuildEditor extends StatefulWidget {
  const SavedBuildEditor({
    super.key,
    required this.edition,
    required this.legendId,
    this.pair,
    this.original,
  });

  final GuideEdition edition;
  final String legendId;
  final WeaponPair? pair;
  final SavedBuild? original;

  @override
  State<SavedBuildEditor> createState() => _SavedBuildEditorState();
}

class _SavedBuildEditorState extends State<SavedBuildEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.original?.name);
  late var _legend = widget.original?.legend.id ?? widget.legendId;
  late String? _first = widget.original?.first.id ?? widget.pair?.first;
  late String? _second = widget.original?.second.id ?? widget.pair?.second;
  late var _two =
      widget.original?.levelTwo ?? _guide?.levelTwo.recommended.name;
  late var _three =
      widget.original?.levelThree ?? _guide?.levelThree.recommended.name;

  LegendGuide? get _guide => widget.edition.entries[_legend]?.guide;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<String, String> _weaponOptions(WeaponsState state) {
    final names = <String, String>{};
    for (final pair in widget.edition.weaponPairs) {
      final parts = pair.title.split(' + ');
      names[pair.first] = parts.length == 2 ? parts.first : pair.first;
      names[pair.second] = parts.length == 2 ? parts.last : pair.second;
    }
    if (widget.original case final build?) {
      names[build.first.id] = build.first.name;
      names[build.second.id] = build.second.name;
    }
    for (final weapon in state.source.data?.weapons ?? const <Weapon>[]) {
      names[weapon.id] = weapon.name;
    }
    return names;
  }

  void _selectLegend(String id) => setState(() {
    _legend = id;
    _two = _guide?.levelTwo.recommended.name;
    _three = _guide?.levelThree.recommended.name;
  });

  void _save(Map<String, String> weapons) {
    if (!_form.currentState!.validate()) return;
    final legend = widget.edition.entries[_legend]?.legend;
    final item = legend == null
        ? widget.original!.legend
        : (id: legend.id, name: legend.name);
    Navigator.pop(
      context,
      SavedBuild(
        id:
            widget.original?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        legend: item,
        first: (id: _first!, name: weapons[_first]!),
        second: (id: _second!, name: weapons[_second]!),
        levelTwo: _two!,
        levelThree: _three!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WeaponsCubit, WeaponsState>(
    builder: (context, state) {
      final weapons = _weaponOptions(state);
      final legends = {
        if (widget.original case final build?)
          build.legend.id: build.legend.name,
        for (final legend in widget.edition.legends) legend.id: legend.name,
      };
      final strings = context.strings;
      return AlertDialog(
        scrollable: true,
        title: Text(
          widget.original == null ? strings.newBuild : strings.editBuild,
        ),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: InputDecoration(labelText: strings.buildName),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? strings.enterBuildName
                      : null,
                ),
                ApehSelect<String>(
                  label: strings.legend,
                  value: _legend,
                  items: legends.keys,
                  labelFor: (id) => legends[id]!,
                  onChanged: _selectLegend,
                ),
                _weapon(
                  strings.firstWeapon,
                  _first,
                  _second,
                  weapons,
                  (id) => setState(() => _first = id),
                ),
                _weapon(
                  strings.secondWeapon,
                  _second,
                  _first,
                  weapons,
                  (id) => setState(() => _second = id),
                ),
                _upgrade(
                  2,
                  _guide?.levelTwo,
                  _two,
                  (name) => setState(() => _two = name),
                ),
                _upgrade(
                  3,
                  _guide?.levelThree,
                  _three,
                  (name) => setState(() => _three = name),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: [_first, _second, _two, _three].contains(null)
                ? null
                : () => _save(weapons),
            child: Text(strings.save),
          ),
        ],
      );
    },
  );

  Widget _weapon(
    String label,
    String? value,
    String? other,
    Map<String, String> weapons,
    ValueChanged<String> select,
  ) => ApehSelect<String>(
    label: label,
    value: value,
    items: weapons.keys.where((id) => id != other),
    labelFor: (id) => weapons[id]!,
    onChanged: select,
  );

  Widget _upgrade(
    int level,
    UpgradeLevel? choices,
    String? value,
    ValueChanged<String> select,
  ) => ApehSelect<String>(
    label: context.strings.level('$level'),
    value: value,
    items: {
      if (choices != null) ...[
        choices.recommended.name,
        choices.alternative.name,
      ],
      ?value,
    },
    onChanged: select,
  );
}
