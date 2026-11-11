import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/link.dart';

import '../l10n/localization.dart';
import '../design/apeh_design.dart';
import 'build_guides.dart';
import 'builds_cubit.dart';
import 'saved_builds_panel.dart';
import 'upgrade_repository.dart';

class BuildsPage extends StatelessWidget {
  const BuildsPage({super.key, required this.onCompare});
  final CompareWeapons onCompare;

  @override
  Widget build(BuildContext context) => BlocBuilder<BuildsCubit, BuildsState>(
    builder: (context, state) => ApehPage(
      title: context.strings.brBuilds,
      description: context.strings.buildDescription,
      children: [
        SavedBuildsPanel(guides: state, onCompare: onCompare),
        const SizedBox(height: 14),
        _EditionUpdate(state: state),
        const SizedBox(height: 14),
        ApehColumns(
          first: _WeaponPairs(state: state, onCompare: onCompare),
          second: _LegendBuilds(state: state),
        ),
      ],
    ),
  );
}

class _EditionUpdate extends StatelessWidget {
  const _EditionUpdate({required this.state});

  final BuildsState state;

  @override
  Widget build(BuildContext context) {
    final edition = state.edition;
    final status = state.guideStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (edition != null)
              Text(
                '${edition.patch} · ${context.strings.guideEdition('${edition.revision}')}',
              ),
            TextButton.icon(
              onPressed: status == GuideUpdateStatus.checking
                  ? null
                  : context.read<BuildsCubit>().refreshGuides,
              icon: const Icon(Icons.sync),
              label: Text(context.strings.checkUpdates),
            ),
          ],
        ),
        if (status != null)
          Text(switch (status) {
            GuideUpdateStatus.checking => context.strings.checkingGuides,
            GuideUpdateStatus.current => context.strings.noGuideUpdates,
            GuideUpdateStatus.updated => context.strings.guidesUpdated,
            GuideUpdateStatus.unavailable =>
              edition == null
                  ? context.strings.guideLoadError
                  : context.strings.guideOffline,
          }, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WeaponPairs extends StatelessWidget {
  const _WeaponPairs({required this.state, required this.onCompare});

  final BuildsState state;
  final CompareWeapons onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(context.strings.weaponPairs, 'weapons'),
          const SizedBox(height: 12),
          ApehSelect<BuildRange>(
            label: context.strings.distance,
            value: state.range,
            items: BuildRange.values,
            labelFor: (range) => switch (range) {
              BuildRange.close => context.strings.closeRange,
              BuildRange.medium => context.strings.mediumRange,
              BuildRange.long => context.strings.longRange,
            },
            onChanged: context.read<BuildsCubit>().selectRange,
          ),
          for (final pair in state.pairs)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 4),
              decoration: BoxDecoration(
                color: context.subtleFill,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    pair.reason,
                    style: TextStyle(color: context.colors.onSurfaceVariant),
                  ),
                  TextButton.icon(
                    onPressed: () => onCompare(pair.first, pair.second),
                    icon: const ApehIcon('weapons', size: 16),
                    label: Text(context.strings.compareWeapons),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.label, this.icon);

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      ),
      ApehIcon(icon, color: context.colors.onSurfaceVariant),
    ],
  );
}

class _LegendBuilds extends StatefulWidget {
  const _LegendBuilds({required this.state});

  final BuildsState state;

  @override
  State<_LegendBuilds> createState() => _LegendBuildsState();
}

class _LegendBuildsState extends State<_LegendBuilds> {
  bool _alternative = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final guide = state.guide;
    final catalog = state.source.data;
    final differs =
        catalog != null &&
        guide != null &&
        !state.source.cached &&
        !catalog.matches(guide);
    return ApehPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(context.strings.legendUpgrades, 'builds'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ApehSelect<BuildLegend>(
                  label: context.strings.legend,
                  value: state.legend,
                  items: state.legends,
                  labelFor: (legend) => legend.name,
                  onChanged: (legend) {
                    setState(() => _alternative = false);
                    context.read<BuildsCubit>().selectLegend(legend);
                  },
                ),
              ),
              if (state.online)
                IconButton(
                  tooltip: context.strings.refreshGuide,
                  onPressed: state.source.loading
                      ? null
                      : context.read<BuildsCubit>().refresh,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          if (state.source.loading) const LinearProgressIndicator(),
          if (state.source.failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                state.source.cached
                    ? context.strings.guideCache
                    : context.strings.upgradeLoadError,
              ),
            ),
          if (guide != null) ...[
            const SizedBox(height: 10),
            ApehSelect<bool>(
              label: context.strings.playStyle,
              value: _alternative,
              items: const [false, true],
              labelFor: (alternative) =>
                  alternative ? guide.alternativeStyle : guide.playStyle,
              onChanged: (alternative) =>
                  setState(() => _alternative = alternative),
            ),
            for (final level in [guide.levelTwo, guide.levelThree])
              _UpgradeCard(
                level: level.level,
                choice: _alternative ? level.alternative : level.recommended,
              ),
          ],
          if (differs) ...[
            const SizedBox(height: 8),
            Text(context.strings.guideMismatch),
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
              uri: upgradeSource(state.legend),
              target: LinkTarget.blank,
              builder: (context, follow) => TextButton(
                onPressed: follow,
                child: Text(
                  [
                    context.strings.guideSource,
                    if (catalog != null && catalog.published.isNotEmpty)
                      catalog.published,
                  ].join(' · '),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.level, required this.choice});

  final int level;
  final UpgradeChoice choice;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.outlineVariant),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 8,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  context.strings.level('$level'),
                  style: mono.copyWith(fontSize: 11, color: ink),
                ),
              ),
            ),
            Expanded(
              child: Text(
                choice.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          choice.reason,
          style: TextStyle(color: context.colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}
