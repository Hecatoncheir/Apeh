import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/link.dart';

import '../design/apeh_design.dart';
import '../l10n/localization.dart';
import '../updates/windows_release.dart';
import '../updates/windows_update_button.dart';
import 'appearance_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.ready,
    required this.onLanguage,
    required this.onTheme,
    required this.onScale,
    required this.client,
  });

  final AppearanceSettings appearance;
  final bool ready;
  final Future<bool> Function(AppLanguage) onLanguage;
  final Future<bool> Function(ThemeMode) onTheme;
  final Future<bool> Function(int) onScale;
  final http.Client client;

  @override
  Widget build(BuildContext context) {
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
                  value: appearance.language,
                  items: AppLanguage.values,
                  labelFor: (value) => switch (value) {
                    AppLanguage.automatic => strings.automatic,
                    AppLanguage.russian => strings.russian,
                    AppLanguage.english => strings.english,
                  },
                  onChanged: ready
                      ? (value) => _save(context, onLanguage(value))
                      : null,
                ),
                ApehSelect<ThemeMode>(
                  label: strings.theme,
                  value: appearance.theme,
                  items: ThemeMode.values,
                  labelFor: (value) => switch (value) {
                    ThemeMode.system => strings.automatic,
                    ThemeMode.light => strings.lightTheme,
                    ThemeMode.dark => strings.darkTheme,
                  },
                  onChanged: ready
                      ? (value) => _save(context, onTheme(value))
                      : null,
                ),
                ApehSelect<int>(
                  label: strings.scale,
                  value: appearance.scale,
                  items: AppearanceSettings.scales,
                  labelFor: (value) => '$value %',
                  onChanged: ready
                      ? (value) => _save(context, onScale(value))
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

class _UpdatesPanel extends StatefulWidget {
  const _UpdatesPanel({required this.client});

  final http.Client client;

  @override
  State<_UpdatesPanel> createState() => _UpdatesPanelState();
}

class _UpdatesPanelState extends State<_UpdatesPanel> {
  late final _installed = _readInstalledVersion();
  Future<Version?>? _published;

  Future<String?> _readInstalledVersion() async {
    if (releaseBuildVersion.isNotEmpty) return releaseBuildVersion;
    try {
      final version = (await PackageInfo.fromPlatform()).version;
      return version.isEmpty ? null : version;
    } on Exception {
      return null;
    }
  }

  bool _isNewer(Version latest, String? installed) {
    try {
      return installed != null && latest > Version.parse(installed);
    } on FormatException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ApehPanel(
      child: FutureBuilder<String?>(
        future: _installed,
        builder: (context, installed) => FutureBuilder<Version?>(
          future: _published,
          builder: (context, published) {
            final latest = published.data;
            final checking =
                published.connectionState == ConnectionState.waiting;
            final current = installed.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  strings.updates,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(strings.installedVersion(current ?? '—'), style: mono),
                if (checking)
                  Text(strings.checkingUpdates)
                else if (published.hasError)
                  Text(strings.checkUpdatesFailed)
                else if (_published != null) ...[
                  if (latest != null)
                    Text(strings.latestVersion(latest.toString()), style: mono),
                  if (current != null &&
                      (latest == null || !_isNewer(latest, current)))
                    Text(strings.noUpdates),
                  if (latest != null &&
                      (current == null || _isNewer(latest, current)))
                    Wrap(
                      spacing: 8,
                      children: [
                        if (current != null)
                          WindowsUpdateButton(
                            client: widget.client,
                            version: current,
                            label: strings.downloadInstall,
                          ),
                        Link(
                          uri: Uri.https(
                            'github.com',
                            '/Hecatoncheir/Apeh/releases/tag/v$latest',
                          ),
                          target: LinkTarget.blank,
                          builder: (_, follow) => TextButton(
                            onPressed: follow,
                            child: Text(strings.releasePage),
                          ),
                        ),
                      ],
                    ),
                ],
                OutlinedButton.icon(
                  onPressed: checking
                      ? null
                      : () {
                          final check = checkPublishedVersion(widget.client);
                          setState(() {
                            _published = check;
                          });
                        },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(strings.checkUpdates),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
