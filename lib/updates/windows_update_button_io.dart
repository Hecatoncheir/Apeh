import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/localization.dart';
import 'windows_release.dart';
import 'windows_update_download.dart';

class WindowsUpdateButton extends StatelessWidget {
  const WindowsUpdateButton({
    super.key,
    required this.client,
    this.version,
    this.label,
  });

  final http.Client client;
  final String? version;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final current = version ?? releaseBuildVersion;
    if (!Platform.isWindows || current.isEmpty) return const SizedBox.shrink();
    void open() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(client: client, version: current),
    );
    if (label case final text?) {
      return FilledButton(onPressed: open, child: Text(text));
    }
    return IconButton(
      icon: const Icon(Icons.system_update_alt),
      tooltip: context.strings.updates,
      onPressed: open,
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.client, required this.version});

  final http.Client client;
  final String version;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  late Future<WindowsRelease?> _latest = _check();
  bool _installing = false;
  Object? _error;

  Future<WindowsRelease?> _check() =>
      checkWindowsRelease(widget.client, widget.version);

  Future<void> _install(WindowsRelease release) async {
    setState(() {
      _installing = true;
      _error = null;
    });
    File? installer;
    try {
      installer = await downloadWindowsInstaller(widget.client, release);
      await Process.start(
        installer.path,
        const [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } on Exception catch (error) {
      if (installer != null) await removeWindowsInstaller(installer);
      if (!mounted) return;
      setState(() {
        _error = error;
        _installing = false;
      });
    }
  }

  String _message(BuildContext context, Object? error, String fallback) =>
      !context.english && error is UpdateException ? error.message : fallback;

  @override
  Widget build(BuildContext context) => FutureBuilder<WindowsRelease?>(
    future: _latest,
    builder: (context, snapshot) {
      final strings = context.strings;
      final release = snapshot.data;
      final checking = snapshot.connectionState != ConnectionState.done;
      return PopScope(
        canPop: !_installing,
        child: AlertDialog(
          title: Text(strings.updates),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.installedVersion(widget.version)),
                const SizedBox(height: 12),
                Text(
                  _error != null
                      ? _message(context, _error, strings.installFailed)
                      : _installing
                      ? strings.installChecking
                      : checking
                      ? strings.checkingUpdates
                      : snapshot.hasError
                      ? _message(
                          context,
                          snapshot.error,
                          strings.checkUpdatesFailed,
                        )
                      : release == null
                      ? strings.noUpdates
                      : strings.availableUpdate(release.version.toString()),
                ),
                if (checking || _installing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _installing ? null : () => Navigator.of(context).pop(),
              child: Text(strings.close),
            ),
            if (!checking && snapshot.hasError)
              TextButton(
                onPressed: () {
                  final check = _check();
                  setState(() {
                    _latest = check;
                  });
                },
                child: Text(strings.retry),
              ),
            if (release != null && !checking)
              FilledButton(
                onPressed: _installing ? null : () => _install(release),
                child: Text(strings.downloadInstall),
              ),
          ],
        ),
      );
    },
  );
}
