import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/localization.dart';
import 'favorite_map_picker.dart';
import 'rotation.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_ui_text.dart';

class RotationReminderDialog extends StatefulWidget {
  const RotationReminderDialog({
    super.key,
    required this.settings,
    this.availableMaps,
  });

  final RotationReminderSettings settings;
  final Iterable<String>? availableMaps;

  @override
  State<RotationReminderDialog> createState() => _RotationReminderDialogState();
}

class _RotationReminderDialogState extends State<RotationReminderDialog> {
  final _form = GlobalKey<FormState>();
  late final _selected = widget.settings.playlists.toSet();
  late List<FavoriteMap> _favorites = widget.settings.favorites;
  late final _minutes = TextEditingController(
    text: widget.settings.minutes.toString(),
  );

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      RotationReminderSettings(
        int.parse(_minutes.text),
        _selected,
        favorites: _favorites,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.availableMaps == null
            ? context.strings.reminders
            : context.strings.favoriteMaps,
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.availableMaps case final maps?)
              SizedBox(
                width: 420,
                child: FavoriteMapPicker(
                  availableMaps: maps,
                  favorites: _favorites,
                  onChanged: (value) => _favorites = value,
                ),
              )
            else
              for (final mode in Playlist.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(playlistLabel(context, mode)),
                  value: _selected.contains(mode),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.add(mode);
                    } else {
                      _selected.remove(mode);
                    }
                  }),
                ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.strings.reminderLead,
                helperText: widget.availableMaps == null
                    ? context.strings.reminderLeadHelp
                    : context.strings.favoriteLeadHelp,
                helperMaxLines: 2,
              ),
              validator: (value) {
                final minutes = int.tryParse(value ?? '');
                if (minutes == null ||
                    minutes < 0 ||
                    minutes > RotationReminderSettings.maxMinutes) {
                  return context.strings.reminderLeadError(
                    '${RotationReminderSettings.maxMinutes}',
                  );
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (defaultTargetPlatform == TargetPlatform.linux) ...[
              const SizedBox(height: 12),
              Text(context.strings.linuxReminders),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(context.strings.save)),
      ],
    );
  }
}
