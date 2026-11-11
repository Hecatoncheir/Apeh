import 'dart:math' as math;

enum Armor {
  none('Без щита', 0),
  white('Белый', 50),
  blue('Синий', 75),
  purple('Фиолетовый', 100),
  mythic('Красный · мифический', 125);

  const Armor(this.label, this.shield);
  final String label;
  final int shield;
  int get total => 100 + shield;
}

class Weapon {
  Weapon.fromJson(Map<String, Object?> json)
    : id = _string(json['slug']),
      name = _string(json['name']),
      category = _string(json['categoryCode']),
      ammo = _ammoTypes(json['ammoTypeCodes']),
      carePackage = json['carePackage'] == true,
      pelletDamage = _positive(json['damage']),
      projectiles = _positiveInt(json['projectilesPerShot']),
      ammoPerShot = _positiveInt(json['ammoPerShot']),
      baseMagazine = _magazine(json, 'base'),
      extendedMagazine = _optionalMagazine(json, 'level3'),
      _mode = _FireMode.fromJson(
        _baseMode(json),
        _optionalPositive(json['rechamberSeconds']),
      ),
      _shieldScale = _optionalPositive(json['shieldDamageScale']) ?? 1,
      _healthScale = _optionalPositive(json['unshieldedDamageScale']) ?? 1,
      _source = Map.unmodifiable({
        for (final key in const [
          'slug',
          'name',
          'categoryCode',
          'ammoTypeCodes',
          'carePackage',
          'damage',
          'projectilesPerShot',
          'ammoPerShot',
          'magazines',
          'rechamberSeconds',
          'shieldDamageScale',
          'unshieldedDamageScale',
        ])
          key: json[key],
        'fireModes': [_baseMode(json)],
      });

  final String id;
  final String name;
  final String category;
  final List<String> ammo;
  final bool carePackage;
  final double pelletDamage;
  final int projectiles;
  final int ammoPerShot;
  final int baseMagazine;
  final int? extendedMagazine;
  final _FireMode _mode;
  final double _shieldScale;
  final double _healthScale;
  final Map<String, Object?> _source;

  double get bodyDamage => pelletDamage * projectiles;
  double get rpm => 60 * _mode.effectiveRate;
  double get dps => bodyDamage * _mode.effectiveRate;
  int get burst => _mode.burst;

  Map<String, Object?> toJson() => _source;

  KillEstimate estimate(Armor armor, {required bool extended}) {
    final equivalentShield = armor.shield / _shieldScale;
    final shieldShots = (equivalentShield / bodyDamage - 1e-6).ceil();
    final overflow = math.max(0.0, shieldShots * bodyDamage - equivalentShield);
    final remainingHealth = math.max(0.0, 100 - overflow);
    final healthShots = (remainingHealth / (bodyDamage * _healthScale) - 1e-6)
        .ceil();
    final shots = shieldShots + healthShots;
    final magazine = extended ? extendedMagazine ?? baseMagazine : baseMagazine;
    final needsReload = magazine > 0 && shots * ammoPerShot > magazine;
    return KillEstimate(shots, needsReload ? null : _mode.timeFor(shots));
  }
}

class KillEstimate {
  const KillEstimate(this.shots, this.seconds);

  final int shots;
  // Без перезарядки оставшегося боезапаса недостаточно.
  final double? seconds;
}

class _FireMode {
  _FireMode.fromJson(Map<String, Object?> json, double? rechamber)
    : burst = _optionalPositive(json['burstCount'])?.toInt() ?? 1,
      _afterBurst = _optionalPositive(json['burstDelaySeconds']),
      _interval = 1 / _positive(json['roundsPerSecond']),
      _rechamber = rechamber ?? 0;

  final int burst;
  final double? _afterBurst;
  final double _interval;
  final double _rechamber;

  double get _singleInterval => math.max(_interval, _rechamber);
  bool get _hasBurst => burst > 1 && _afterBurst != null;

  double get effectiveRate => _hasBurst
      ? burst / ((burst - 1) * _interval + _afterBurst!)
      : 1 / _singleInterval;

  double timeFor(int shots) {
    final intervals = shots - 1;
    if (!_hasBurst) return intervals * _singleInterval;
    final pauses = intervals ~/ burst;
    return pauses * _afterBurst! + (intervals - pauses) * _interval;
  }
}

Map<String, Object?> _baseMode(Map<String, Object?> json) {
  final modes = json['fireModes'];
  if (modes is List<Object?>) {
    for (final mode in modes) {
      if (mode is Map<String, Object?> && mode['slug'] == 'base') return mode;
    }
  }
  throw const FormatException('Неизвестный режим стрельбы.');
}

String _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException('Отсутствует описание оружия.');
}

List<String> _ammoTypes(Object? value) => value is List<Object?>
    ? List.unmodifiable(value.whereType<String>())
    : const [];

double? _optionalPositive(Object? value) =>
    value is num && value >= .001 && value <= 100000 ? value.toDouble() : null;

double _positive(Object? value) {
  final number = _optionalPositive(value);
  if (number == null) {
    throw const FormatException('Неверная характеристика оружия.');
  }
  return number;
}

int _positiveInt(Object? value) {
  if (value is int && value > 0) return value;
  throw const FormatException('Неверное количество боеприпасов.');
}

int? _optionalMagazine(Map<String, Object?> json, String key) {
  final magazines = json['magazines'];
  final value = magazines is Map<String, Object?> ? magazines[key] : null;
  return value is int && value >= 0 ? value : null;
}

int _magazine(Map<String, Object?> json, String key) =>
    _optionalMagazine(json, key) ??
    (throw const FormatException('Нет данных о магазине.'));
