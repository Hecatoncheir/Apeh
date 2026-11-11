import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rotation.dart';
import 'rotation_reminder_plan.dart';

class RotationReminderDialog extends StatefulWidget {
  const RotationReminderDialog({super.key, required this.settings});

  final RotationReminderSettings settings;

  @override
  State<RotationReminderDialog> createState() => _RotationReminderDialogState();
}

class _RotationReminderDialogState extends State<RotationReminderDialog> {
  final _form = GlobalKey<FormState>();
  late final _selected = widget.settings.playlists.toSet();
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
    Navigator.of(context)
        .pop(RotationReminderSettings(int.parse(_minutes.text), _selected));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Напоминания о смене карт'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final mode in Playlist.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(mode.label),
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
              decoration: const InputDecoration(
                labelText: 'За сколько минут',
                helperText: '0 — в момент смены карты',
              ),
              validator: (value) {
                final minutes = int.tryParse(value ?? '');
                if (minutes == null ||
                    minutes < 0 ||
                    minutes > RotationReminderSettings.maxMinutes) {
                  return 'Введите от 0 до ${RotationReminderSettings.maxMinutes} минут';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (defaultTargetPlatform == TargetPlatform.linux) ...[
              const SizedBox(height: 12),
              const Text('На Linux напоминания приходят, пока Apeh открыт.'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
