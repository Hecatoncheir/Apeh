import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

class WindowsTray {
  static const _channel = MethodChannel('apeh/windows_tray');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> configure(bool enabled, AppLocalizations strings) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('configure', {
        'enabled': enabled,
        'open': strings.openApeh,
        'quit': strings.quitApeh,
      });
    } on Exception catch (error) {
      debugPrint('Не удалось настроить трей Apeh: $error');
    }
  }
}
