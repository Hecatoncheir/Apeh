import 'package:flutter/material.dart';

import 'weapon.dart';
import 'weapons_view_model.dart';

class WeaponsPage extends StatelessWidget {
  const WeaponsPage({super.key, required this.model});

  final WeaponsViewModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Apeh',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: const Color(0xFF111419),
          actions: [
            IconButton(
              tooltip: 'Обновить каталог оружия',
              onPressed: model.loading ? null : model.refresh,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(child: _content(context)),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final catalog = model.catalog;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Сравнение оружия',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (catalog != null)
              Text(
                'Apex Weapon Stats · ${catalog.season} · ${_date(catalog.patch)}'
                '${model.cached ? ' · сохранённая копия' : ''}',
              ),
            if (model.loading) const LinearProgressIndicator(),
            if (model.failed)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Не удалось обновить каталог Apex Weapon Stats.'),
              ),
            if (catalog != null) ...[
              const SizedBox(height: 20),
              if (model.selectionUnavailable)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Один из выбранных вариантов отсутствует в каталоге. Выберите замену.',
                  ),
                ),
              Text(
                'Броня цели',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final armor in Armor.values)
                    ChoiceChip(
                      label: Text('${armor.label} · ${armor.total}'),
                      selected: model.armor == armor,
                      onSelected: (_) => model.selectArmor(armor),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: const Text('Магазин III уровня'),
                  selected: model.extended,
                  onSelected: model.selectMagazine,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final left = _WeaponCard(
                    model: model,
                    weapons: catalog.weapons,
                    left: true,
                  );
                  final right = _WeaponCard(
                    model: model,
                    weapons: catalog.weapons,
                    left: false,
                  );
                  if (constraints.maxWidth < 730) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, const SizedBox(height: 12), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'TTK считается от первого выстрела. Все попадания в корпус вблизи, '
                'все дробины попадают. Время подготовки, перезарядка и отложенные эффекты '
                'не входят в расчёт.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeaponCard extends StatelessWidget {
  const _WeaponCard({
    required this.model,
    required this.weapons,
    required this.left,
  });

  final WeaponsViewModel model;
  final List<Weapon> weapons;
  final bool left;

  @override
  Widget build(BuildContext context) {
    final weapon = model.selected(left: left);
    final estimate = weapon.estimate(model.armor, extended: model.extended);
    final seconds = estimate.seconds;
    final rounds = estimate.shots * weapon.ammoPerShot;
    final magazine = model.extended
        ? weapon.extendedMagazine ?? weapon.baseMagazine
        : weapon.baseMagazine;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: left ? 'Первое оружие' : 'Второе оружие',
              child: DropdownButton<String>(
                isExpanded: true,
                value: weapon.id,
                onChanged: (id) {
                  if (id != null) model.selectWeapon(id, left: left);
                },
                items: [
                  for (final item in weapons)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Text(
              [
                _category(weapon.category),
                ...weapon.ammo.map(_ammo),
                if (weapon.carePackage) 'Груз снабжения',
              ].join(' · '),
            ),
            const SizedBox(height: 16),
            const Text('Время убийства (TTK)'),
            Text(
              seconds == null
                  ? 'Нужна перезарядка'
                  : '${_number(seconds, 3)} с',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'Выстрелов ${estimate.shots}${rounds == estimate.shots ? '' : ' · расход патронов $rounds'}',
            ),
            const Divider(height: 24),
            _Stat('Урон за выстрел', _number(weapon.bodyDamage, 2)),
            if (weapon.projectiles > 1)
              _Stat(
                'Снаряды за выстрел',
                '${weapon.projectiles} × ${_number(weapon.pelletDamage, 2)}',
              ),
            _Stat('Темп стрельбы', '${_number(weapon.rpm, 1)} выстр./мин'),
            if (weapon.burst > 1)
              _Stat('Выстрелов в очереди', '${weapon.burst}'),
            _Stat('Базовый урон в секунду', _number(weapon.dps, 1)),
            _Stat('Магазин', magazine == 0 ? 'Без магазина' : '$magazine'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

String _number(double value, int digits) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _category(String code) => switch (code) {
  'ar' => 'Штурмовая винтовка',
  'smg' => 'Пистолет-пулемёт',
  'lmg' => 'Пулемёт',
  'marksman' => 'Марксманское',
  'sniper' => 'Снайперская винтовка',
  'shotgun' => 'Дробовик',
  'pistol' => 'Пистолет',
  _ => 'Оружие',
};

String _ammo(String code) => switch (code) {
  'light' || 'bullet' => 'лёгкие',
  'heavy' || 'highcal' => 'тяжёлые',
  'energy' || 'special' => 'энергетические',
  'sniper' => 'снайперские',
  'shotgun' => 'дробь',
  'arrows' => 'стрелы',
  _ => code,
};
