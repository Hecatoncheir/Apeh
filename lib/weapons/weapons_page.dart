import 'package:flutter/material.dart';

import '../l10n/localization.dart';
import '../design/apeh_design.dart';
import 'weapon.dart';
import 'weapons_view_model.dart';

class WeaponsPage extends StatelessWidget {
  const WeaponsPage({super.key, required this.model});

  final WeaponsViewModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final catalog = model.catalog;
    return ApehPage(
      title: context.strings.weapons,
      description: context.strings.weaponDescription,
      actions: [
        IconButton(
          tooltip: context.strings.refreshWeapons,
          onPressed: model.loading ? null : model.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        if (model.loading) const LinearProgressIndicator(),
        if (model.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(context.strings.weaponsLoadError),
          ),
        if (catalog != null) ...[
          if (model.selectionUnavailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(context.strings.weaponUnavailable),
            ),
          _WeaponControls(model: model, weapons: catalog.weapons),
          const SizedBox(height: 14),
          ApehColumns(
            first: _Comparison(model: model),
            second: _KillTime(model: model),
            firstFlex: 6,
            secondFlex: 5,
          ),
          const SizedBox(height: 14),
          Text(
            [
              'Apex Weapon Stats',
              catalog.season,
              _date(catalog.patch),
              if (model.cached) context.strings.cachedCopy,
            ].join(' · '),
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _WeaponControls extends StatelessWidget {
  const _WeaponControls({required this.model, required this.weapons});

  final WeaponsViewModel model;
  final List<Weapon> weapons;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 570 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final left in [true, false])
              SizedBox(
                width: width,
                child: ApehSelect<Weapon>(
                  label: left
                      ? context.strings.firstWeapon
                      : context.strings.secondWeapon,
                  value: model.selected(left: left),
                  items: weapons,
                  labelFor: (weapon) => weapon.name,
                  onChanged: (weapon) =>
                      model.selectWeapon(weapon.id, left: left),
                ),
              ),
            SizedBox(
              width: width,
              child: ApehSelect<Armor>(
                label: context.strings.targetArmor,
                value: model.armor,
                items: Armor.values,
                labelFor: (armor) =>
                    '${_armorLabel(context, armor)} · ${armor.total} HP',
                onChanged: model.selectArmor,
              ),
            ),
            FilterChip(
              label: Text(context.strings.extendedMagazine),
              selected: model.extended,
              onSelected: model.selectMagazine,
            ),
          ],
        );
      },
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.model});

  final WeaponsViewModel model;

  @override
  Widget build(BuildContext context) {
    final left = model.selected(left: true);
    final right = model.selected(left: false);
    final stats = [
      (
        context.strings.weaponType,
        _category(context, left.category),
        _category(context, right.category),
      ),
      (
        context.strings.ammo,
        _ammoLabel(context, left),
        _ammoLabel(context, right),
      ),
      (
        context.strings.damagePerShot,
        _number(context, left.bodyDamage, 2),
        _number(context, right.bodyDamage, 2),
      ),
      if (left.projectiles > 1 || right.projectiles > 1)
        (
          context.strings.projectiles,
          _projectiles(context, left),
          _projectiles(context, right),
        ),
      (
        context.strings.roundsPerMinute,
        _number(context, left.rpm, 1),
        _number(context, right.rpm, 1),
      ),
      if (left.burst > 1 || right.burst > 1)
        (context.strings.burstShots, '${left.burst}', '${right.burst}'),
      (
        context.strings.damagePerSecond,
        _number(context, left.dps, 1),
        _number(context, right.dps, 1),
      ),
      (
        context.strings.magazine,
        _magazineLabel(context, left),
        _magazineLabel(context, right),
      ),
    ];
    final title = Theme.of(context).textTheme.titleLarge;
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.strings.stats, style: title),
          const SizedBox(height: 8),
          _ComparisonRow(
            context.strings.metric,
            left.name,
            right.name,
            header: true,
          ),
          for (final (label, first, second) in stats)
            _ComparisonRow(label, first, second),
        ],
      ),
    );
  }

  String _magazineLabel(BuildContext context, Weapon weapon) {
    final magazine = model.extended
        ? weapon.extendedMagazine ?? weapon.baseMagazine
        : weapon.baseMagazine;
    return magazine == 0 ? context.strings.noMagazine : '$magazine';
  }

  String _projectiles(BuildContext context, Weapon weapon) =>
      '${weapon.projectiles} × ${_number(context, weapon.pelletDamage, 2)}';

  String _ammoLabel(BuildContext context, Weapon weapon) => [
    ...weapon.ammo.map((code) => _ammo(context, code)),
    if (weapon.carePackage) context.strings.carePackage,
  ].join(' · ');
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(
    this.label,
    this.left,
    this.right, {
    this.header = false,
  });

  final String label;
  final String left;
  final String right;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final labelStyle = style?.copyWith(
      fontVariations: const [FontVariation.weight(750)],
    );
    final valueStyle = header ? labelStyle : style;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Expanded(flex: 5, child: Text(label, style: labelStyle)),
          Expanded(flex: 4, child: Text(left, style: valueStyle)),
          Expanded(flex: 4, child: Text(right, style: valueStyle)),
        ],
      ),
    );
  }
}

class _KillTime extends StatelessWidget {
  const _KillTime({required this.model});

  final WeaponsViewModel model;

  @override
  Widget build(BuildContext context) {
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.timeToKill,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            context.strings.bodyHits('${model.armor.total}'),
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final left in [true, false])
            _estimate(context, model.selected(left: left)),
          const SizedBox(height: 4),
          Text(
            context.strings.ttkHelp,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimate(BuildContext context, Weapon weapon) {
    final estimate = weapon.estimate(model.armor, extended: model.extended);
    final seconds = estimate.seconds;
    final rounds = estimate.shots * weapon.ammoPerShot;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(weapon.name),
                Text(
                  seconds == null
                      ? context.strings.reloadNeeded
                      : context.strings.seconds(_number(context, seconds, 3)),
                  style: mono.copyWith(
                    fontVariations: const [FontVariation.weight(700)],
                  ),
                ),
              ],
            ),
          ),
          Text(
            [
              context.strings.shots('${estimate.shots}'),
              if (rounds != estimate.shots)
                context.strings.ammoSpent('$rounds'),
            ].join(' · '),
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _number(BuildContext context, double value, int digits) {
  final formatted = value.toStringAsFixed(digits);
  return context.english ? formatted : formatted.replaceAll('.', ',');
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _category(BuildContext context, String code) => switch (code) {
  'ar' => context.strings.assaultRifle,
  'smg' => context.strings.smg,
  'lmg' => context.strings.lmg,
  'marksman' => context.strings.marksman,
  'sniper' => context.strings.sniper,
  'shotgun' => context.strings.shotgun,
  'pistol' => context.strings.pistol,
  _ => context.strings.weapons,
};

String _ammo(BuildContext context, String code) => switch (code) {
  'light' || 'bullet' => context.strings.lightAmmo,
  'heavy' || 'highcal' => context.strings.heavyAmmo,
  'energy' || 'special' => context.strings.energyAmmo,
  'sniper' => context.strings.sniperAmmo,
  'shotgun' => context.strings.shotgunAmmo,
  'arrows' => context.strings.arrowAmmo,
  _ => code,
};

String _armorLabel(BuildContext context, Armor armor) => switch (armor) {
  Armor.none => context.strings.noShield,
  Armor.white => context.strings.whiteShield,
  Armor.blue => context.strings.blueShield,
  Armor.purple => context.strings.purpleShield,
  Armor.mythic => context.strings.redShield,
};
