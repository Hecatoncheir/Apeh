enum BuildRange {
  close('Ближняя'),
  medium('Средняя'),
  long('Дальняя');

  const BuildRange(this.label);
  final String label;
}

class WeaponPair {
  const WeaponPair(
    this.range,
    this.first,
    this.second,
    this.title,
    this.reason,
  );

  final BuildRange range;
  final String first;
  final String second;
  final String title;
  final String reason;
}

class BuildLegend {
  const BuildLegend(this.id, this.name);

  final String id;
  final String name;
}

const buildLegends = [
  BuildLegend('alter', 'Alter'),
  BuildLegend('ash', 'Ash'),
  BuildLegend('axle', 'Axle'),
  BuildLegend('ballistic', 'Ballistic'),
  BuildLegend('bangalore', 'Bangalore'),
  BuildLegend('bloodhound', 'Bloodhound'),
  BuildLegend('catalyst', 'Catalyst'),
  BuildLegend('caustic', 'Caustic'),
  BuildLegend('conduit', 'Conduit'),
  BuildLegend('crypto', 'Crypto'),
  BuildLegend('fuse', 'Fuse'),
  BuildLegend('gibraltar', 'Gibraltar'),
  BuildLegend('horizon', 'Horizon'),
  BuildLegend('lifeline', 'Lifeline'),
  BuildLegend('loba', 'Loba'),
  BuildLegend('mad-maggie', 'Mad Maggie'),
  BuildLegend('mirage', 'Mirage'),
  BuildLegend('newcastle', 'Newcastle'),
  BuildLegend('octane', 'Octane'),
  BuildLegend('pathfinder', 'Pathfinder'),
  BuildLegend('rampart', 'Rampart'),
  BuildLegend('revenant', 'Revenant'),
  BuildLegend('seer', 'Seer'),
  BuildLegend('sparrow', 'Sparrow'),
  BuildLegend('valkyrie', 'Valkyrie'),
  BuildLegend('vantage', 'Vantage'),
  BuildLegend('wattson', 'Wattson'),
  BuildLegend('wraith', 'Wraith'),
];

class UpgradeChoice {
  const UpgradeChoice(this.name, this.reason);

  final String name;
  final String reason;
}

class UpgradeLevel {
  const UpgradeLevel(this.level, this.recommended, this.alternative);

  final int level;
  final UpgradeChoice recommended;
  final UpgradeChoice alternative;
}

class LegendGuide {
  const LegendGuide(
    this.playStyle,
    this.alternativeStyle,
    this.levelTwo,
    this.levelThree, {
    this.catalogLegacyNames = const {},
  });

  final String playStyle;
  final String alternativeStyle;
  final Set<String> catalogLegacyNames;
  final UpgradeLevel levelTwo;
  final UpgradeLevel levelThree;

  Iterable<String> get upgradeNames => [
    levelTwo.recommended.name,
    levelTwo.alternative.name,
    levelThree.recommended.name,
    levelThree.alternative.name,
  ];
}
