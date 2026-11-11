import 'package:flutter/material.dart';

import 'rotation.dart';
import 'rotation_reminder_dialog.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_reminders.dart';
import 'rotation_time_zone.dart';
import 'rotation_view_model.dart';

class RotationPage extends StatelessWidget {
  const RotationPage({super.key, required this.model});

  final RotationViewModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apeh',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF111419),
        actions: [
          if (model.reminders case final reminders?)
            ListenableBuilder(
              listenable: reminders,
              builder: (context, _) => IconButton(
                tooltip: 'Напоминания о смене карт',
                icon: Icon(
                  reminders.settings.enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                ),
                onPressed: reminders.busy
                    ? null
                    : () => _openReminderDialog(context, reminders),
              ),
            ),
          ListenableBuilder(
            listenable: model,
            builder: (context, _) => IconButton(
              tooltip: 'Обновить карты',
              onPressed: model.canRefresh ? model.refresh : null,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (model.canLoad)
            ListenableBuilder(
              listenable: model,
              builder: (context, _) => IconButton(
                tooltip: 'Настроить ключ API',
                onPressed: model.canChangeKey
                    ? () => _openKeyDialog(context)
                    : null,
                icon: Icon(model.hasKey ? Icons.key : Icons.key_outlined),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([model, model.reminders]),
          builder: (context, _) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final snapshot = model.snapshot;
    final zone = model.timeZone;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Ротация карт',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              switch (snapshot) {
                _ when model.demo => 'Демонстрация · пример расписания',
                final value? when model.fromCache =>
                  'Сохранённое расписание · ${_scheduleTime(context, value.updatedAt, model.now, zone)}',
                final value? =>
                  'Apex Legends Status · обновлено ${_scheduleTime(context, value.updatedAt, model.now, zone)}',
                _ => 'Apex Legends Status',
              },
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFFB4BCC9)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: 'Часовой пояс',
                child: TextButton.icon(
                  onPressed: model.canChangeTimeZone
                      ? () => _openTimeZoneDialog(context)
                      : null,
                  icon: const Icon(Icons.schedule),
                  label: Text(zone.label),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (model.loading) const LinearProgressIndicator(),
            if (model.message case final message?)
              _notice(context, message, Icons.info_outline),
            if (model.storageMessage case final message?)
              _notice(context, message, Icons.info_outline),
            if (model.timeZoneMessage case final message?)
              _notice(context, message, Icons.info_outline),
            if (model.reminders?.message case final message?)
              _notice(context, message, Icons.notifications_none),
            if (!model.canLoad && !model.demo) ...[
              _notice(
                context,
                'Актуальное расписание доступно в установленном приложении.',
                Icons.desktop_windows_outlined,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: model.showDemo,
                  child: const Text('Открыть демонстрацию'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (model.loading) const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 16.0;
                final width = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - gap) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final mode in Playlist.values)
                      SizedBox(
                        width: width,
                        child: _MapCard(
                          mode: mode,
                          rotation: snapshot?.playlists[mode],
                          now: model.now,
                          timeZone: zone,
                          emptyMessage: _emptyMessage(snapshot),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _emptyMessage(RotationSnapshot? snapshot) {
    if (snapshot != null) return 'Источник не передал расписание';
    if (model.loading) return 'Загружаем расписание…';
    return 'Расписание недоступно';
  }

  Widget _notice(BuildContext context, String message, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(leading: Icon(icon), title: Text(message)),
    );
  }

  Future<void> _openKeyDialog(BuildContext context) async {
    final key = await showDialog<String>(
      context: context,
      builder: (_) => _KeyDialog(hasKey: model.hasKey),
    );
    if (context.mounted && key != null) {
      await model.setKey(key.isEmpty ? null : key);
    }
  }

  Future<void> _openTimeZoneDialog(BuildContext context) async {
    final zone = await showDialog<RotationTimeZone>(
      context: context,
      builder: (_) => _TimeZoneDialog(selected: model.timeZone, now: model.now),
    );
    if (context.mounted && zone != null) await model.setTimeZone(zone);
  }

  Future<void> _openReminderDialog(
    BuildContext context,
    RotationReminders reminders,
  ) async {
    final value = await showDialog<RotationReminderSettings>(
      context: context,
      builder: (_) => RotationReminderDialog(settings: reminders.settings),
    );
    if (context.mounted && value != null) await reminders.save(value);
  }
}

class _TimeZoneDialog extends StatefulWidget {
  const _TimeZoneDialog({required this.selected, required this.now});

  final RotationTimeZone selected;
  final DateTime now;

  @override
  State<_TimeZoneDialog> createState() => _TimeZoneDialogState();
}

class _TimeZoneDialogState extends State<_TimeZoneDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final choices = RotationTimeZone.choices.where((zone) {
      return zone.label.toLowerCase().contains(_query) ||
          zone.id.toLowerCase().contains(_query);
    }).toList();

    return AlertDialog(
      title: const Text('Часовой пояс'),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Найти город или пояс',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: choices.isEmpty
                  ? const Center(child: Text('Часовой пояс не найден'))
                  : ListView.builder(
                      key: ValueKey(_query),
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final zone = choices[index];
                        final selected = zone.id == widget.selected.id;
                        return ListTile(
                          title: Text(zone.label),
                          subtitle: Text(zone.offsetLabel(widget.now)),
                          selected: selected,
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.of(context).pop(zone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

class _KeyDialog extends StatefulWidget {
  const _KeyDialog({required this.hasKey});

  final bool hasKey;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  final _form = GlobalKey<FormState>();
  final _key = TextEditingController();

  void _submit() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_key.text.trim());
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ключ Apex Legends Status'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _key,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Ключ API',
            helperText: 'Без ключа Apeh загружает расписание с сайта.',
            helperMaxLines: 2,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Вставьте ключ API'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        if (widget.hasKey)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Удалить ключ'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.mode,
    required this.rotation,
    required this.now,
    required this.timeZone,
    required this.emptyMessage,
  });

  final Playlist mode;
  final PlaylistRotation? rotation;
  final DateTime now;
  final RotationTimeZone timeZone;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = switch (mode) {
      Playlist.ranked => (Icons.military_tech, const Color(0xFFFFA183)),
      Playlist.battleRoyale => (Icons.public, const Color(0xFFFFCB77)),
      Playlist.mixtape => (Icons.shuffle, const Color(0xFF83D5CA)),
      Playlist.wildcard => (Icons.bolt, const Color(0xFFC8ABFF)),
    };
    final active = rotation?.activeAt(now);
    final upcoming = rotation?.upcomingAt(now);
    final image = active?.image;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF1A1F27),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF343D4B)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        accent.withValues(alpha: .18),
                        const Color(0xFF1A1F27),
                      ],
                    ),
                  ),
                  child: image == null
                      ? null
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              image.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            const ColoredBox(color: Color(0xAA111419)),
                          ],
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 12,
                            children: [
                              Text(
                                mode.label,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (active?.variant case final variant?)
                                Text(variant),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Сейчас',
                      style: TextStyle(color: Color(0xFFB4BCC9)),
                    ),
                    Text(
                      active?.name ??
                          (rotation == null
                              ? emptyMessage
                              : 'Текущая карта неизвестна'),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'До смены ${_countdown(active.end.difference(now))}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF343D4B)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Дальше',
                  style: TextStyle(color: Color(0xFFB4BCC9)),
                ),
                Text(
                  upcoming?.name ?? 'Нет данных',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (upcoming != null)
                  Text(
                    [
                      upcoming.variant,
                      'с ${_scheduleTime(context, upcoming.start, now, timeZone)}',
                      if (active == null)
                        'через ${_countdown(upcoming.start.difference(now))}',
                    ].nonNulls.join(' · '),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _time(BuildContext context, DateTime time) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(TimeOfDay.fromDateTime(time), alwaysUse24HourFormat: true);

String _scheduleTime(
  BuildContext context,
  DateTime time,
  DateTime now,
  RotationTimeZone zone,
) {
  final date = zone.at(time);
  final localNow = zone.at(now);
  final clock = _time(context, date);
  if (DateUtils.isSameDay(date, localNow)) return clock;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month в $clock';
}

String _countdown(Duration remaining) {
  final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
  final days = seconds ~/ 86400;
  final clock = [
    seconds ~/ 3600 % 24,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((part) => part.toString().padLeft(2, '0')).join(':');
  return days == 0 ? clock : '$days д $clock';
}
