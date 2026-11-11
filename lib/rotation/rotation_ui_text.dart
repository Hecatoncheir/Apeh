import 'package:flutter/widgets.dart';

import '../l10n/localization.dart';
import 'rotation.dart';
import 'rotation_time_zone.dart';

String playlistLabel(BuildContext context, Playlist mode) =>
    mode == Playlist.battleRoyale ? context.strings.regularBr : mode.label;

String zoneLabel(BuildContext context, RotationTimeZone zone) {
  if (zone == RotationTimeZone.device) return context.strings.deviceZone;
  if (!context.english) return zone.label;
  return zone.id.split('/').last.replaceAll('_', ' ');
}

String rotationNotice(BuildContext context, String notice) {
  if (!context.english) return notice;
  const fallback = ' Используется публичное расписание.';
  if (notice.endsWith(fallback)) {
    final error = notice.substring(0, notice.length - fallback.length);
    return '${rotationNotice(context, error)} Using the public schedule.';
  }
  return switch (notice) {
    'Apex Legends Status не принял ключ API.' =>
      'Apex Legends Status rejected the API key.',
    'Слишком много запросов. Попробуйте обновить позже.' =>
      'Too many requests. Try again later.',
    'Не удалось прочитать расписание Apex Legends Status.' =>
      'Could not read the Apex Legends Status schedule.',
    'Не удалось прочитать сохранённый часовой пояс.' =>
      'Could not read the saved time zone.',
    'Часовой пояс действует до закрытия приложения.' =>
      'The time zone will apply until the app closes.',
    'Не удалось прочитать сохранённый ключ API.' =>
      'Could not read the saved API key.',
    'Ключ будет действовать до закрытия приложения.' =>
      'The key will apply until the app closes.',
    'Не удалось удалить сохранённый ключ API.' =>
      'Could not remove the saved API key.',
    'Не удалось прочитать настройки напоминаний.' =>
      'Could not read reminder settings.',
    'Не удалось сохранить настройки напоминаний.' =>
      'Could not save reminder settings.',
    'Не удалось настроить уведомления. Проверьте настройки системы.' =>
      'Could not set up notifications. Check your system settings.',
    'Разрешите уведомления Apeh в настройках системы.' =>
      'Allow Apeh notifications in your system settings.',
    'Android может задерживать напоминания без разрешения на точные сигналы.' =>
      'Android may delay reminders unless exact alarms are allowed.',
    _ => 'Could not load the schedule. Check your connection.',
  };
}
