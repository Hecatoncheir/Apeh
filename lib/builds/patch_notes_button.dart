import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/link.dart';

import '../l10n/localization.dart';
import 'builds_cubit.dart';
import 'patch_highlights.dart';

class PatchNotesButton extends StatelessWidget {
  const PatchNotesButton(this.section, {super.key});

  final PatchSection section;

  @override
  Widget build(BuildContext context) {
    final highlights = context.select(
      (BuildsCubit cubit) => cubit.state.highlights,
    );
    if (highlights == null) return const SizedBox.shrink();
    final changes = highlights.changes.where(
      (change) => change.section == section,
    );
    if (changes.isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.notes),
      label: Text(context.strings.patchChanges),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(highlights.title),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
          actions: [
            Link(
              uri: highlights.source,
              builder: (_, follow) => TextButton(
                onPressed: follow,
                child: Text(context.strings.officialPatchNotes),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.close),
            ),
          ],
        ),
      ),
    );
  }
}
