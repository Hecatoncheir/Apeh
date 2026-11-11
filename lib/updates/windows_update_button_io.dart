import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      builder: (_) => BlocProvider(
        create: (_) => _UpdateCubit(client, current),
        child: _UpdateDialog(version: current),
      ),
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

enum _UpdatePhase {
  checking,
  current,
  available,
  checkFailed,
  installing,
  installFailed,
}

typedef _UpdateState = ({
  _UpdatePhase phase,
  WindowsRelease? release,
  Object? error,
});

class _UpdateCubit extends Cubit<_UpdateState> {
  _UpdateCubit(this._client, this._version)
    : super((phase: _UpdatePhase.checking, release: null, error: null)) {
    unawaited(check());
  }

  final http.Client _client;
  final String _version;

  Future<void> check() async {
    _show(_UpdatePhase.checking);
    try {
      final release = await checkWindowsRelease(_client, _version);
      _show(
        release == null ? _UpdatePhase.current : _UpdatePhase.available,
        release: release,
      );
    } on Exception catch (error) {
      _show(_UpdatePhase.checkFailed, error: error);
    }
  }

  Future<void> install(WindowsRelease release) async {
    if (isClosed || state.phase == _UpdatePhase.installing) return;
    _show(_UpdatePhase.installing, release: release);
    File? installer;
    try {
      installer = await downloadWindowsInstaller(_client, release);
      await Process.start(
        installer.path,
        const [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } on Exception catch (error) {
      if (installer != null) await removeWindowsInstaller(installer);
      _show(_UpdatePhase.installFailed, release: release, error: error);
    }
  }

  void _show(_UpdatePhase phase, {WindowsRelease? release, Object? error}) {
    if (!isClosed) emit((phase: phase, release: release, error: error));
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<_UpdateCubit, _UpdateState>(builder: _dialog);

  Widget _dialog(BuildContext context, _UpdateState state) {
    final strings = context.strings;
    final installing = state.phase == _UpdatePhase.installing;
    final checking = state.phase == _UpdatePhase.checking;
    return PopScope(
      canPop: !installing,
      child: AlertDialog(
        title: Text(strings.updates),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.installedVersion(version)),
              const SizedBox(height: 12),
              Text(_message(context, state)),
              if (checking || installing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: _actions(context, state),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, _UpdateState state) {
    final cubit = context.read<_UpdateCubit>();
    final strings = context.strings;
    final installing = state.phase == _UpdatePhase.installing;
    return [
      TextButton(
        onPressed: installing ? null : () => Navigator.of(context).pop(),
        child: Text(strings.close),
      ),
      if (state.phase == _UpdatePhase.checkFailed)
        TextButton(onPressed: cubit.check, child: Text(strings.retry)),
      if (state.release case final release?)
        FilledButton(
          onPressed: installing ? null : () => cubit.install(release),
          child: Text(strings.downloadInstall),
        ),
    ];
  }

  String _message(BuildContext context, _UpdateState state) {
    if (state.error case final UpdateException error when !context.english) {
      return error.message;
    }
    final strings = context.strings;
    return switch (state.phase) {
      _UpdatePhase.checking => strings.checkingUpdates,
      _UpdatePhase.current => strings.noUpdates,
      _UpdatePhase.available => strings.availableUpdate(
        state.release!.version.toString(),
      ),
      _UpdatePhase.checkFailed => strings.checkUpdatesFailed,
      _UpdatePhase.installing => strings.installChecking,
      _UpdatePhase.installFailed => strings.installFailed,
    };
  }
}
