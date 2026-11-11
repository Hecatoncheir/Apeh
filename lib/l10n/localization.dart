import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

extension ApehLocalization on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);
  bool get english => strings.localeName == 'en';
}
