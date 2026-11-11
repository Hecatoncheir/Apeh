import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/localization.dart';
import '../design/apeh_design.dart';
import 'legend_board.dart';
import 'legends_cubit.dart';

class LegendsPage extends StatelessWidget {
  const LegendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return ApehPage(
        title: context.strings.legends,
        description: context.strings.legendDescription,
        children: [ApehPanel(child: Text(context.strings.nativeLegends))],
      );
    }
    return BlocBuilder<LegendsCubit, LegendsState>(builder: _content);
  }

  Widget _content(BuildContext context, LegendsState state) {
    final board = state.source.data;
    return ApehPage(
      title: context.strings.legends,
      description: context.strings.legendDescription,
      actions: [
        SizedBox(
          width: 190,
          child: ApehSelect<LegendRank>(
            label: context.strings.rank,
            value: state.rank,
            items: LegendRank.values,
            labelFor: (rank) => switch (rank) {
              LegendRank.all => context.strings.allPlayers,
              LegendRank.unranked => context.strings.rookie,
              LegendRank.bronze => context.strings.bronze,
              LegendRank.silver => context.strings.silver,
              LegendRank.gold => context.strings.gold,
              LegendRank.platinum => context.strings.platinum,
              LegendRank.diamond => context.strings.diamond,
              LegendRank.masterPred => context.strings.masterPredator,
            },
            onChanged: context.read<LegendsCubit>().selectRank,
          ),
        ),
        IconButton(
          tooltip: context.strings.refreshLegends,
          onPressed: state.source.loading
              ? null
              : context.read<LegendsCubit>().refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: board == null
          ? null
          : _LegendBoardLayout(board: board, state: state),
      children: [
        if (state.source.loading) const LinearProgressIndicator(),
        if (state.source.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(context.strings.legendLoadError),
          ),
        if (board != null) ...[
          Text(
            'Apex Legends Status · ${state.source.cached ? context.strings.saved : context.strings.fetched} '
            '${_date(board.fetchedAt.toLocal())}, '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(board.fetchedAt.toLocal()), alwaysUse24HourFormat: true)}'
            ' · ${context.strings.allModes}',
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LegendBoardLayout extends StatelessWidget {
  const _LegendBoardLayout({required this.board, required this.state});

  final LegendBoard board;
  final LegendsState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 680;
      final chart = _TrendPanel(board: board, state: state, compact: !wide);
      final grid = _PickList(board: board, state: state);
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .63,
              ),
              child: SingleChildScrollView(primary: false, child: chart),
            ),
            Expanded(child: grid),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Expanded(flex: 6, child: grid),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(primary: false, child: chart),
            ),
          ),
        ],
      );
    },
  );
}

class _PickList extends StatefulWidget {
  const _PickList({required this.board, required this.state});

  final LegendBoard board;
  final LegendsState state;

  @override
  State<_PickList> createState() => _PickListState();
}

class _PickListState extends State<_PickList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _PickList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board != widget.board) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ApehPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.strings.pickRate,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ApehIcon('legends', color: context.colors.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const ValueKey('legend-pick-grid'),
                controller: _scroll,
                padding: const EdgeInsets.only(right: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    final preferredWidth = MediaQuery.textScalerOf(context)
                        .scale(100)
                        .clamp(100.0, 155.0);
                    final width = constraints.maxWidth;
                    final columns = math.max(
                      1,
                      (width + gap) ~/ (preferredWidth + gap),
                    );
                    final tileWidth = (width - (columns - 1) * gap) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final pick in widget.board.picks)
                          SizedBox(
                            width: tileWidth,
                            child: _LegendTile(
                              pick: pick,
                              selected:
                                  widget.state.selection?.name == pick.name,
                              onTap: () => context
                                  .read<LegendsCubit>()
                                  .selectLegend(pick.name),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.pick,
    required this.selected,
    required this.onTap,
  });

  final LegendPick pick;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? context.colors.secondaryContainer : context.subtleFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? context.colors.primary : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(pick.name),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Column(
            spacing: 4,
            children: [
              _Portrait(pick: pick),
              Text(pick.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                _percent(context, pick.percent),
                style: mono.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.pick});

  final LegendPick pick;

  @override
  Widget build(BuildContext context) {
    final portrait = pick.portrait;
    const size = 66.0;
    final placeholder = ColoredBox(
      color: context.colors.outlineVariant,
      child: Center(
        child: Text(
          pick.name
              .split(' ')
              .where((word) => word.isNotEmpty)
              .take(2)
              .map((word) => word.characters.first)
              .join(),
          style: display(21).copyWith(color: context.colors.onSurface),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: portrait == null
            ? placeholder
            : Image.network(
                portrait.toString(),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.board,
    required this.state,
    required this.compact,
  });

  final LegendBoard board;
  final LegendsState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = state.selection;
    final points = board.history[selected?.name] ?? const <PickPoint>[];
    return ApehPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.pickTrend,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (compact) ...[
            const SizedBox(height: 5),
            if (selected != null) Text(selected.name),
          ] else ...[
            const SizedBox(height: 12),
            ApehSelect<String>(
              label: context.strings.legend,
              value: selected?.name,
              items: board.picks.map((pick) => pick.name),
              onChanged: context.read<LegendsCubit>().selectLegend,
            ),
          ],
          SizedBox(height: compact ? 8 : 14),
          if (points.isEmpty)
            Text(context.strings.historyUnavailable)
          else
            _TrendChart(points: points, height: compact ? 104 : 144),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.height});

  final List<PickPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final low = points.map((point) => point.percent).reduce(math.min);
    final high = points.map((point) => point.percent).reduce(math.max);
    final min = math.max(0.0, low - .1);
    final max = math.min(100.0, high + .1);
    final latest = points.last;
    final weekAgo = latest.day.subtract(const Duration(days: 7));
    final baseline = points.where((point) => point.day == weekAgo).firstOrNull;
    final delta = baseline == null ? null : latest.percent - baseline.percent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${_percent(context, latest.percent)} · ${_date(latest.day)}',
              style: mono.copyWith(fontSize: 21),
            ),
            if (delta != null)
              Text(
                context.strings.weekDelta(
                  '${delta >= 0 ? '+' : '−'}${_number(context, delta.abs())}',
                ),
                style: mono.copyWith(
                  color: delta >= 0
                      ? context.positiveText
                      : context.negativeText,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_percent(context, max)),
                  Text(_percent(context, min)),
                ],
              ),
            ),
            Expanded(
              child: Semantics(
                label: context.strings.chartSemantics(
                  _date(points.first.day),
                  _date(latest.day),
                ),
                child: SizedBox(
                  height: height,
                  child: CustomPaint(
                    painter: _TrendPainter(points, min, max, colors),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_date(points.first.day)),
              if (points.length > 1) Text(_date(latest.day)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.min, this.max, this.colors);

  final List<PickPoint> points;
  final double min;
  final double max;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = colors.outlineVariant;
    for (final fraction in [0.0, .5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final area = Paint()..color = colors.secondaryContainer;
    final dot = Paint()..color = colors.primaryContainer;
    final start = points.first.day;
    final span = math.max(1, points.last.day.difference(start).inDays);
    Offset? previous;
    DateTime? previousDay;
    for (final point in points) {
      final x = size.width * point.day.difference(start).inDays / span;
      final y = size.height * (max - point.percent) / (max - min);
      final position = Offset(x, y);
      if (previous != null && point.day.difference(previousDay!).inDays == 1) {
        final fill = Path()
          ..moveTo(previous.dx, size.height)
          ..lineTo(previous.dx, previous.dy)
          ..lineTo(x, y)
          ..lineTo(x, size.height)
          ..close();
        canvas.drawPath(fill, area);
        canvas.drawLine(previous, position, line);
      }
      canvas.drawCircle(position, 3, line);
      canvas.drawCircle(position, 2, dot);
      previous = position;
      previousDay = point.day;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.colors != colors;
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';

String _number(BuildContext context, double value) {
  final number = value.toStringAsFixed(2);
  return context.english ? number : number.replaceAll('.', ',');
}

String _percent(BuildContext context, double value) =>
    '${_number(context, value)}%';
