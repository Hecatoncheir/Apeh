import 'package:flutter/material.dart';

import '../l10n/localization.dart';
import '../design/apeh_design.dart';
import 'rotation.dart';
import 'rotation_reminder_dialog.dart';
import 'rotation_reminder_plan.dart';
import 'rotation_reminders.dart';
import 'rotation_time_zone.dart';
import 'rotation_ui_text.dart';
import 'rotation_view_model.dart';

class RotationPage extends StatelessWidget {
  const RotationPage({super.key, required this.model, this.updateAction});

  final RotationViewModel model;
  final Widget? updateAction;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, model.reminders]),
    builder: (context, _) => _body(context),
  );

  Widget _body(BuildContext context) {
    final snapshot = model.snapshot;
    final zone = model.timeZone;
    final reminders = model.reminders;
    return ApehPage(
      title: context.strings.rotation,
      description: context.strings.rotationDescription,
      actions: [
        Tooltip(
          message: context.strings.timeZone,
          child: OutlinedButton.icon(
            onPressed: model.canChangeTimeZone
                ? () => _openTimeZoneDialog(context)
                : null,
            icon: const ApehIcon('clock', size: 17),
            label: Text(zoneLabel(context, zone)),
          ),
        ),
        if (reminders != null)
          IconButton(
            tooltip: context.strings.reminders,
            style: reminders.settings.enabled
                ? IconButton.styleFrom(backgroundColor: accent)
                : null,
            icon: ApehIcon(
              'bell',
              color: reminders.settings.enabled ? ink : null,
            ),
            onPressed: reminders.busy
                ? null
                : () => _openReminderDialog(context, reminders),
          ),
        IconButton(
          tooltip: context.strings.refreshMaps,
          onPressed: model.canRefresh ? model.refresh : null,
          icon: const Icon(Icons.refresh),
        ),
        if (model.canLoad)
          IconButton(
            tooltip: context.strings.configureApiKey,
            onPressed: model.canChangeKey
                ? () => _openKeyDialog(context)
                : null,
            icon: Icon(model.hasKey ? Icons.key : Icons.key_outlined),
          ),
        ?updateAction,
      ],
      children: [
        Text(switch (snapshot) {
          _ when model.demo => context.strings.demoSchedule,
          final value? when model.fromCache => context.strings.cachedSchedule(
            _scheduleTime(context, value.updatedAt, model.now, zone),
          ),
          final value? => context.strings.updatedSchedule(
            _scheduleTime(context, value.updatedAt, model.now, zone),
          ),
          _ => 'Apex Legends Status',
        }, style: TextStyle(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: 10),
        if (model.loading) const LinearProgressIndicator(),
        if (model.message case final message?)
          _notice(rotationNotice(context, message), Icons.info_outline),
        if (model.storageMessage case final message?)
          _notice(rotationNotice(context, message), Icons.info_outline),
        if (model.timeZoneMessage case final message?)
          _notice(rotationNotice(context, message), Icons.info_outline),
        if (reminders?.message case final message?)
          _notice(rotationNotice(context, message), Icons.notifications_none),
        if (!model.canLoad && !model.demo) ...[
          _notice(
            context.strings.nativeSchedule,
            Icons.desktop_windows_outlined,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: model.showDemo,
              child: Text(context.strings.openDemo),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (model.loading) const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final width = constraints.maxWidth >= 670
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
                      emptyMessage: _emptyMessage(context, snapshot),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _emptyMessage(BuildContext context, RotationSnapshot? snapshot) {
    if (snapshot != null) return context.strings.noScheduleFromSource;
    if (model.loading) return context.strings.loadingSchedule;
    return context.strings.scheduleUnavailable;
  }

  Widget _notice(String message, IconData icon) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(leading: Icon(icon), title: Text(message)),
  );

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
      return zoneLabel(context, zone).toLowerCase().contains(_query) ||
          zone.id.toLowerCase().contains(_query);
    }).toList();

    return AlertDialog(
      title: Text(context.strings.timeZone),
      content: SizedBox(
        width: 360,
        height: (MediaQuery.sizeOf(context).height * .56).clamp(120, 380),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: context.strings.searchZone,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: choices.isEmpty
                  ? Center(child: Text(context.strings.zoneNotFound))
                  : ListView.builder(
                      key: ValueKey(_query),
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final zone = choices[index];
                        final selected = zone.id == widget.selected.id;
                        return ListTile(
                          title: Text(zoneLabel(context, zone)),
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
          child: Text(context.strings.cancel),
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
      title: Text(context.strings.alsKey),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _key,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.strings.apiKey,
            helperText: context.strings.apiKeyHelp,
            helperMaxLines: 2,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? context.strings.enterApiKey
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        if (widget.hasKey)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(context.strings.removeApiKey),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.strings.save)),
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
    final icon = switch (mode) {
      Playlist.ranked => 'ranked',
      Playlist.battleRoyale => 'br',
      Playlist.mixtape => 'mixtape',
      Playlist.wildcard => 'wildcard',
    };
    final active = rotation?.activeAt(now);
    final upcoming = rotation?.upcomingAt(now);
    final image = active?.image;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xFF38392E),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image != null)
                        Image.network(
                          image.toString(),
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x30171814), Color(0xF0171814)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).width >= 900
                      ? (MediaQuery.sizeOf(context).height * .22).clamp(
                          154,
                          220,
                        )
                      : 154,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: mode == Playlist.ranked ? accent : surface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ApehIcon(icon, size: 15, color: ink),
                              const SizedBox(width: 6),
                              Text(
                                playlistLabel(context, mode),
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  fontVariations: [FontVariation.weight(800)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 9,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            runSpacing: 6,
                            spacing: 12,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      context.strings.now,
                                      if (active?.variant case final variant?
                                          when variant != mode.label)
                                        variant,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: surface,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    active?.name ??
                                        (rotation == null
                                            ? emptyMessage
                                            : context.strings.unknownMap),
                                    style: display(active == null ? 20 : 28)
                                        .copyWith(color: surface),
                                  ),
                                ],
                              ),
                              if (active != null)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '${context.strings.timeRemaining} ',
                                        style: const TextStyle(
                                          color: surface,
                                          fontSize: 11,
                                        ),
                                      ),
                                      TextSpan(
                                        text: _countdown(
                                          context,
                                          active.end.difference(now),
                                        ),
                                        style: mono.copyWith(
                                          color: accent,
                                          fontSize: 20,
                                          fontVariations: const [
                                            FontVariation.weight(700),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (active != null)
                            LinearProgressIndicator(
                              value: _elapsed(active),
                              color: accent,
                              backgroundColor: Colors.white30,
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 3,
                              semanticsLabel: context.strings.rotationProgress,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: upcoming == null ? null : () => _openSchedule(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(
                  children: [
                    Text(
                      context.strings.next,
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            upcoming?.name ?? context.strings.noData,
                            style: const TextStyle(
                              fontVariations: [FontVariation.weight(800)],
                            ),
                          ),
                          if (upcoming?.variant case final variant?
                              when variant != mode.label)
                            Text(
                              variant,
                              style: TextStyle(
                                color: context.colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (upcoming != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          [
                            context.strings.startsAt(
                              _scheduleTime(
                                context,
                                upcoming.start,
                                now,
                                timeZone,
                              ),
                            ),
                            if (active == null)
                              context.strings.startsIn(
                                _countdown(
                                  context,
                                  upcoming.start.difference(now),
                                ),
                              ),
                          ].join(' · '),
                          style: mono.copyWith(fontSize: 11),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const ApehIcon('chevron', size: 15),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _elapsed(MapSlot slot) =>
      (now.difference(slot.start).inMilliseconds /
              slot.end.difference(slot.start).inMilliseconds)
          .clamp(0.0, 1.0);

  void _openSchedule(BuildContext context) {
    final slots = rotation!.slots.where((slot) => slot.end.isAfter(now));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(playlistLabel(context, mode)),
        scrollable: true,
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slot in slots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text([slot.name, ?slot.variant].join(' · ')),
                  subtitle: Text(
                    '${_scheduleTime(context, slot.start, now, timeZone)} — '
                    '${_scheduleTime(context, slot.end, now, timeZone)}',
                    style: mono.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.close),
          ),
        ],
      ),
    );
  }
}

String _time(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _scheduleTime(
  BuildContext context,
  DateTime time,
  DateTime now,
  RotationTimeZone zone,
) {
  final date = zone.at(time);
  final localNow = zone.at(now);
  final clock = _time(date);
  if (DateUtils.isSameDay(date, localNow)) return clock;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return context.strings.dateAtTime('$day.$month', clock);
}

String _countdown(BuildContext context, Duration remaining) {
  final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
  final days = seconds ~/ 86400;
  final clock = [
    seconds ~/ 3600 % 24,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((part) => part.toString().padLeft(2, '0')).join(':');
  return days == 0 ? clock : context.strings.daysClock('$days', clock);
}
