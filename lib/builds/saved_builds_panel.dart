import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/apeh_design.dart';
import '../l10n/localization.dart';
import 'build_guides.dart';
import 'builds_cubit.dart';
import 'patch_highlights.dart';
import 'saved_build_editor.dart';
import 'saved_builds.dart';

typedef CompareWeapons = void Function(String first, String second);

class SavedBuildsPanel extends StatelessWidget {
  const SavedBuildsPanel({
    super.key,
    required this.guides,
    required this.onCompare,
  });

  final BuildsState guides;
  final CompareWeapons onCompare;

  @override
  Widget build(BuildContext context) {
    final (:items, :busy) = context.watch<SavedBuildsCubit>().state;
    final strings = context.strings;
    final canEdit = !busy && items != null && guides.edition != null;
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.savedBuilds,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: canEdit ? () => _edit(context) : null,
                icon: const Icon(Icons.add),
                label: Text(strings.newBuild),
              ),
            ],
          ),
          if (items == null && !busy) Text(strings.buildsReadError),
          if (items?.isEmpty ?? false) Text(strings.noSavedBuilds),
          for (final build in items ?? const <SavedBuild>[])
            _SavedBuildCard(
              key: ValueKey(build.id),
              item: build,
              guide: guides.edition?.entries[build.legend.id]?.guide,
              highlights: guides.highlights,
              onCompare: () => onCompare(build.first.id, build.second.id),
              onEdit: canEdit ? () => _edit(context, original: build) : null,
              onRemove: busy ? null : () => _remove(context, build),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, {SavedBuild? original}) async {
    final cubit = context.read<SavedBuildsCubit>();
    final build = await showDialog<SavedBuild>(
      context: context,
      builder: (_) => SavedBuildEditor(
        edition: guides.edition!,
        legendId: guides.legendId,
        pair:
            guides.pairs.firstOrNull ?? guides.edition?.weaponPairs.firstOrNull,
        original: original,
      ),
    );
    if (build != null && context.mounted) {
      await _save(context, cubit.save(build));
    }
  }

  Future<void> _remove(BuildContext context, SavedBuild build) async {
    final cubit = context.read<SavedBuildsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.removeBuild),
        content: Text(build.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.removeBuild),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _save(context, cubit.remove(build));
    }
  }

  Future<void> _save(BuildContext context, Future<bool> saved) async {
    if (!await saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.settingsSaveError)),
      );
    }
  }
}

class _SavedBuildCard extends StatelessWidget {
  const _SavedBuildCard({
    super.key,
    required this.item,
    required this.guide,
    required this.highlights,
    required this.onCompare,
    required this.onEdit,
    required this.onRemove,
  });

  final SavedBuild item;
  final LegendGuide? guide;
  final PatchHighlights? highlights;
  final VoidCallback onCompare;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  bool _matches(PatchHighlight change) => switch (change.section) {
    PatchSection.legends => change.id == item.legend.id,
    PatchSection.weapons =>
      change.id == item.first.id || change.id == item.second.id,
  };

  bool _missing(UpgradeLevel? choices, String name) =>
      choices != null &&
      choices.recommended.name != name &&
      choices.alternative.name != name;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final changes = highlights?.changes.where(_matches) ?? const [];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${item.legend.name} · ${item.first.name} + ${item.second.name}',
            ),
            _upgrade(context, 2, item.levelTwo, guide?.levelTwo),
            _upgrade(context, 3, item.levelThree, guide?.levelThree),
            if (changes.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('${strings.patchChanges} · ${highlights!.title}'),
                children: [
                  for (final change in changes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(change.name),
                      subtitle: Text(
                        change.description(english: context.english),
                      ),
                    ),
                ],
              ),
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: onCompare,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(strings.compareWeapons),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: strings.editBuild,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: strings.removeBuild,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _upgrade(
    BuildContext context,
    int level,
    String name,
    UpgradeLevel? choices,
  ) => Text(
    '${context.strings.level('$level')} · $name'
    '${_missing(choices, name) ? ' · ${context.strings.upgradeChanged}' : ''}',
  );
}
