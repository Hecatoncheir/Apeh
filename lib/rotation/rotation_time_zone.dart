import 'package:timezone/data/latest.dart' as database;
import 'package:timezone/timezone.dart' as tz;

class RotationTimeZone {
  const RotationTimeZone._(this.id, this.label, this._location);

  static const device = RotationTimeZone._('device', 'Пояс устройства', null);
  static final choices = _loadChoices();
  static final _byId = {for (final zone in choices) zone.id: zone};

  final String id;
  final String label;
  final tz.Location? _location;

  static RotationTimeZone fromId(String? id) =>
      id == null || id == device.id ? device : _byId[id] ?? device;

  DateTime at(DateTime instant) => switch (_location) {
    final location? => tz.TZDateTime.from(instant, location),
    null => instant.toLocal(),
  };

  String offsetLabel(DateTime instant) {
    final minutes = at(instant).timeZoneOffset.inMinutes;
    if (minutes == 0) return 'UTC';
    final sign = minutes.isNegative ? '−' : '+';
    final absolute = minutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final remainder = (absolute % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$remainder';
  }
}

const _cityNames = {
  'Europe/Kaliningrad': 'Калининград',
  'Europe/Moscow': 'Москва',
  'Europe/Samara': 'Самара',
  'Asia/Yekaterinburg': 'Екатеринбург',
  'Asia/Omsk': 'Омск',
  'Asia/Novosibirsk': 'Новосибирск',
  'Asia/Krasnoyarsk': 'Красноярск',
  'Asia/Irkutsk': 'Иркутск',
  'Asia/Yakutsk': 'Якутск',
  'Asia/Vladivostok': 'Владивосток',
  'Asia/Magadan': 'Магадан',
  'Asia/Kamchatka': 'Петропавловск-Камчатский',
  'Europe/Minsk': 'Минск',
  'Asia/Almaty': 'Алматы',
  'Europe/London': 'Лондон',
  'Europe/Berlin': 'Берлин',
  'Europe/Paris': 'Париж',
  'Asia/Tokyo': 'Токио',
  'America/New_York': 'Нью-Йорк',
  'America/Los_Angeles': 'Лос-Анджелес',
};

List<RotationTimeZone> _loadChoices() {
  database.initializeTimeZones();
  final locations = tz.timeZoneDatabase.locations;
  final ids =
      locations.keys
          .where((id) => id.contains('/') && !id.startsWith('Etc/'))
          .toList()
        ..sort();
  return List.unmodifiable([
    RotationTimeZone.device,
    RotationTimeZone._('UTC', 'UTC', tz.UTC),
    for (final id in _cityNames.keys)
      if (locations[id] case final location?)
        RotationTimeZone._(id, _cityNames[id]!, location),
    for (final id in ids)
      if (!_cityNames.containsKey(id))
        RotationTimeZone._(id, id.replaceAll('_', ' '), locations[id]!),
  ]);
}
