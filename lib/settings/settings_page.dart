import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/link.dart';

import '../design/apeh_design.dart';
import '../l10n/localization.dart';
import '../updates/windows_release.dart';
import '../updates/windows_update_button.dart';
import 'appearance_cubit.dart';
import 'appearance_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.client});

  final http.Client client;

  @override
  Widget build(BuildContext context) {
    final (:settings, :ready) = context.watch<AppearanceCubit>().state;
    final cubit = context.read<AppearanceCubit>();
    final strings = context.strings;
    return ApehPage(
      title: strings.settings,
      description: '',
      children: [
        ApehColumns(
          first: ApehPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(
                  strings.appearance,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!ready) const LinearProgressIndicator(),
                ApehSelect<AppLanguage>(
                  label: strings.language,
                  value: settings.language,
                  items: AppLanguage.values,
                  labelFor: (value) => switch (value) {
                    AppLanguage.automatic => strings.automatic,
                    AppLanguage.russian => strings.russian,
                    AppLanguage.english => strings.english,
                  },
                  onChanged: ready
                      ? (value) => _save(context, cubit.setLanguage(value))
                      : null,
                ),
                ApehSelect<ThemeMode>(
                  label: strings.theme,
                  value: settings.theme,
                  items: ThemeMode.values,
                  labelFor: (value) => switch (value) {
                    ThemeMode.system => strings.automatic,
                    ThemeMode.light => strings.lightTheme,
                    ThemeMode.dark => strings.darkTheme,
                  },
                  onChanged: ready
                      ? (value) => _save(context, cubit.setTheme(value))
                      : null,
                ),
                ApehSelect<int>(
                  label: strings.scale,
                  value: settings.scale,
                  items: AppearanceSettings.scales,
                  labelFor: (value) => '$value %',
                  onChanged: ready
                      ? (value) => _save(context, cubit.setScale(value))
                      : null,
                ),
              ],
            ),
          ),
          second: _UpdatesPanel(client: client),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Future<bool> result) async {
    if (!await result && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.settingsSaveError)),
      );
    }
  }
}

enum _VersionCheck { idle, checking, complete, failed }

typedef _Versions = ({String? installed, Version? latest, _VersionCheck check});

class _VersionsCubit extends Cubit<_Versions> {
  _VersionsCubit(this._client)
    : super((installed: null, latest: null, check: _VersionCheck.idle)) {
    unawaited(_readInstalledVersion());
  }

  final http.Client _client;

  Future<void> _readInstalledVersion() async {
    try {
      final version = releaseBuildVersion.isNotEmpty
          ? releaseBuildVersion
          : (await PackageInfo.fromPlatform()).version;
      if (!isClosed && version.isNotEmpty) {
        emit((installed: version, latest: state.latest, check: state.check));
      }
    } on Exception {
      // Версию по-прежнему можно проверить на GitHub.
    }
  }

  Future<void> check() async {
    if (isClosed || state.check == _VersionCheck.checking) return;
    _show(_VersionCheck.checking);
    try {
      final version = await checkPublishedVersion(_client);
      _show(_VersionCheck.complete, latest: version);
    } on Exception {
      _show(_VersionCheck.failed);
    }
  }

  void _show(_VersionCheck check, {Version? latest}) {
    if (!isClosed) {
      emit((installed: state.installed, latest: latest, check: check));
    }
  }
}

class _UpdatesPanel extends StatelessWidget {
  const _UpdatesPanel({required this.client});

  final http.Client client;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _VersionsCubit(client),
    child: BlocBuilder<_VersionsCubit, _Versions>(builder: _panel),
  );

  Widget _panel(BuildContext context, _Versions state) {
    final strings = context.strings;
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(strings.updates, style: Theme.of(context).textTheme.titleLarge),
          Text(strings.installedVersion(state.installed ?? '—'), style: mono),
          ..._result(context, state),
          OutlinedButton.icon(
            onPressed: state.check == _VersionCheck.checking
                ? null
                : context.read<_VersionsCubit>().check,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(strings.checkUpdates),
          ),
        ],
      ),
    );
  }

  List<Widget> _result(BuildContext context, _Versions state) =>
      switch (state.check) {
        _VersionCheck.idle => const [],
        _VersionCheck.checking => [Text(context.strings.checkingUpdates)],
        _VersionCheck.failed => [Text(context.strings.checkUpdatesFailed)],
        _VersionCheck.complete => _publishedVersion(context, state),
      };

  List<Widget> _publishedVersion(BuildContext context, _Versions state) {
    final strings = context.strings;
    final latest = state.latest;
    final current = state.installed;
    final updateAvailable =
        latest != null && (current == null || _isNewer(latest, current));
    return [
      if (latest != null)
        Text(strings.latestVersion(latest.toString()), style: mono),
      if (current != null && !updateAvailable) Text(strings.noUpdates),
      if (updateAvailable) _releaseActions(context, latest, current),
    ];
  }

  bool _isNewer(Version latest, String installed) {
    try {
      return latest > Version.parse(installed);
    } on FormatException {
      return false;
    }
  }

  Widget _releaseActions(
    BuildContext context,
    Version latest,
    String? current,
  ) => Wrap(
    spacing: 8,
    children: [
      if (current != null)
        WindowsUpdateButton(
          client: client,
          version: current,
          label: context.strings.downloadInstall,
        ),
      Link(
        uri: Uri.https(
          'github.com',
          '/Hecatoncheir/Apeh/releases/tag/v$latest',
        ),
        target: LinkTarget.blank,
        builder: (context, follow) => TextButton(
          onPressed: follow,
          child: Text(context.strings.releasePage),
        ),
      ),
    ],
  );
}
