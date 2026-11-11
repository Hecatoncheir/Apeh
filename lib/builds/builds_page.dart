import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import 'build_guides.dart';
import 'builds_view_model.dart';
import 'upgrade_repository.dart';

class BuildsPage extends StatelessWidget {
  const BuildsPage({super.key, required this.model, required this.onCompare});

  final BuildsViewModel model;
  final ValueChanged<WeaponPair> onCompare;

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
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    'Сборки для BR',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  _EditionUpdate(model: model),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final pairs = _WeaponPairs(
                        model: model,
                        onCompare: onCompare,
                      );
                      final upgrades = _LegendBuilds(model: model);
                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            pairs,
                            const SizedBox(height: 24),
                            upgrades,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: pairs),
                          const SizedBox(width: 20),
                          Expanded(child: upgrades),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditionUpdate extends StatelessWidget {
  const _EditionUpdate({required this.model});

  final BuildsViewModel model;

  @override
  Widget build(BuildContext context) {
    final edition = model.edition;
    final status = model.guideStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (edition != null)
              Text('${edition.patch} · выпуск ${edition.revision}'),
            TextButton.icon(
              onPressed: status == GuideUpdateStatus.checking
                  ? null
                  : model.refreshGuides,
              icon: const Icon(Icons.sync),
              label: const Text('Проверить обновления'),
            ),
          ],
        ),
        if (status != null)
          Text(switch (status) {
            GuideUpdateStatus.checking => 'Проверяем рекомендации…',
            GuideUpdateStatus.current => 'Новых выпусков нет.',
            GuideUpdateStatus.updated => 'Рекомендации обновлены.',
            GuideUpdateStatus.unavailable =>
              edition == null
                  ? 'Не удалось открыть рекомендации.'
                  : 'Обновление недоступно. Открыт выпуск с устройства.',
          }, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WeaponPairs extends StatelessWidget {
  const _WeaponPairs({required this.model, required this.onCompare});

  final BuildsViewModel model;
  final ValueChanged<WeaponPair> onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Пары оружия', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final range in BuildRange.values)
              ChoiceChip(
                label: Text(range.label),
                selected: model.range == range,
                onSelected: (_) => model.selectRange(range),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final pair in model.pairs)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(pair.reason),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => onCompare(pair),
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Сравнить оружие'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LegendBuilds extends StatelessWidget {
  const _LegendBuilds({required this.model});

  final BuildsViewModel model;

  @override
  Widget build(BuildContext context) {
    final guide = model.guide;
    final catalog = model.catalog;
    final theme = Theme.of(context);
    final differs =
        catalog != null &&
        guide != null &&
        !model.cached &&
        !catalog.matches(guide);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Улучшения легенд', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButton<BuildLegend>(
                isExpanded: true,
                value: model.legend,
                onChanged: (legend) {
                  if (legend != null) model.selectLegend(legend);
                },
                items: [
                  for (final legend in model.legends)
                    DropdownMenuItem(value: legend, child: Text(legend.name)),
                ],
              ),
            ),
            if (model.online)
              IconButton(
                tooltip: 'Обновить справочник',
                onPressed: model.loading ? null : model.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        if (model.loading) const LinearProgressIndicator(),
        if (model.failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              model.cached
                  ? 'Справочник недоступен. Открыта сохранённая копия.'
                  : 'Не удалось обновить улучшения.',
            ),
          ),
        if (guide != null) ...[
          _UpgradeCard(guide: guide, level: guide.levelTwo),
          _UpgradeCard(guide: guide, level: guide.levelThree),
        ],
        if (differs) ...[
          const SizedBox(height: 8),
          const Text(
            'Состав улучшений в справочнике отличается от этого выпуска.',
          ),
        ],
        if (catalog != null && (differs || guide == null)) ...[
          for (final upgrade in catalog.upgrades)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(upgrade.name),
                subtitle: Text(upgrade.effect),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Link(
            uri: upgradeSource(model.legend),
            target: LinkTarget.blank,
            builder: (context, follow) => TextButton(
              onPressed: follow,
              child: Text(
                [
                  'Справочник apex.source.gs',
                  if (catalog != null && catalog.published.isNotEmpty)
                    catalog.published,
                ].join(' · '),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.guide, required this.level});

  final LegendGuide guide;
  final UpgradeLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Уровень ${level.level}', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Text(guide.playStyle, style: theme.textTheme.labelLarge),
            Text(
              level.recommended.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Text(level.recommended.reason),
            const Divider(height: 20),
            Text(guide.alternativeStyle, style: theme.textTheme.labelLarge),
            Text(level.alternative.name, style: theme.textTheme.titleMedium),
            Text(level.alternative.reason),
          ],
        ),
      ),
    );
  }
}
