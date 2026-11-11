import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'windows_release.dart';
import 'windows_update_download.dart';

const _version = String.fromEnvironment('APEH_VERSION');

class WindowsUpdateButton extends StatelessWidget {
  const WindowsUpdateButton({super.key, required this.client});

  final http.Client client;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows || _version.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.system_update_alt),
      tooltip: 'Обновления Apeh',
      onPressed: () => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(client: client),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.client});

  final http.Client client;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  late Future<WindowsRelease?> _latest = _check();
  bool _installing = false;
  String? _error;

  Future<WindowsRelease?> _check() =>
      checkWindowsRelease(widget.client, _version);

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
        _error = _message(error, 'Не удалось запустить обновление.');
        _installing = false;
      });
    }
  }

  String _message(Object? error, String fallback) =>
      error is UpdateException ? error.message : fallback;

  @override
  Widget build(BuildContext context) => FutureBuilder<WindowsRelease?>(
    future: _latest,
    builder: (context, snapshot) {
      final release = snapshot.data;
      final checking = snapshot.connectionState != ConnectionState.done;
      return PopScope(
        canPop: !_installing,
        child: AlertDialog(
          title: const Text('Обновления Apeh'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Установленная версия $_version'),
                const SizedBox(height: 12),
                Text(
                  _error ??
                      (_installing
                          ? 'Скачиваем и проверяем установщик…'
                          : checking
                          ? 'Проверяем наличие обновлений…'
                          : snapshot.hasError
                          ? _message(
                              snapshot.error,
                              'Не удалось проверить обновления.',
                            )
                          : release == null
                          ? 'Новых версий нет.'
                          : 'Доступна версия ${release.version}. Apeh закроется, когда запустится установщик.'),
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
              child: const Text('Закрыть'),
            ),
            if (!checking && snapshot.hasError)
              TextButton(
                onPressed: () => setState(() => _latest = _check()),
                child: const Text('Повторить'),
              ),
            if (release != null && !checking)
              FilledButton(
                onPressed: _installing ? null : () => _install(release),
                child: const Text('Скачать и установить'),
              ),
          ],
        ),
      );
    },
  );
}
