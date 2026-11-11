import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'legend_board.dart';
import 'legends_view_model.dart';

class LegendsPage extends StatelessWidget {
  const LegendsPage({super.key, required this.model});

  final LegendsViewModel? model;

  @override
  Widget build(BuildContext context) {
    final data = model;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apeh',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF111419),
        actions: [
          if (data != null)
            ListenableBuilder(
              listenable: data,
              builder: (context, _) => IconButton(
                tooltip: 'Обновить популярность',
                onPressed: data.loading ? null : data.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: data == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Популярность легенд доступна в установленном Apeh.',
                  ),
                ),
              )
            : ListenableBuilder(
                listenable: data,
                builder: (context, _) => _content(context, data),
              ),
      ),
    );
  }

  Widget _content(BuildContext context, LegendsViewModel model) {
    final board = model.board;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Популярность легенд',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Доля выбранных легенд среди отслеживаемых игроков, все режимы.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<LegendRank>(
                value: model.rank,
                onChanged: (rank) {
                  if (rank != null) model.selectRank(rank);
                },
                items: [
                  for (final rank in LegendRank.values)
                    DropdownMenuItem(value: rank, child: Text(rank.label)),
                ],
              ),
            ),
            if (model.loading) const LinearProgressIndicator(),
            if (model.failed)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Не удалось обновить данные Apex Legends Status.'),
              ),
            if (board != null) ...[
              const SizedBox(height: 8),
              Text(
                'Apex Legends Status · ${model.fromCache ? 'сохранено' : 'получено'} '
                '${_date(board.fetchedAt.toLocal())}, '
                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(board.fetchedAt.toLocal()), alwaysUse24HourFormat: true)}',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, size) {
                  final chart = _TrendPanel(board: board, model: model);
                  final list = _PickList(board: board, model: model);
                  if (size.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [chart, const SizedBox(height: 16), list],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: list),
                      const SizedBox(width: 16),
                      Expanded(child: chart),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickList extends StatelessWidget {
  const _PickList({required this.board, required this.model});

  final LegendBoard board;
  final LegendsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final pick in board.picks)
            ListTile(
              dense: true,
              selected: model.selection?.name == pick.name,
              selectedTileColor: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              onTap: () => model.selectLegend(pick.name),
              leading: _Portrait(pick: pick),
              title: Text(pick.name),
              trailing: Text(_percent(pick.percent)),
            ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.pick});

  final LegendPick pick;

  @override
  Widget build(BuildContext context) {
    final portrait = pick.portrait;
    const placeholder = Icon(Icons.person_outline);
    return SizedBox.square(
      dimension: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: portrait == null
            ? placeholder
            : Image.network(
                portrait.toString(),
                fit: BoxFit.cover,
                cacheWidth: 96,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.board, required this.model});

  final LegendBoard board;
  final LegendsViewModel model;

  @override
  Widget build(BuildContext context) {
    final selected = model.selection;
    final points = board.history[selected?.name] ?? const <PickPoint>[];
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Динамика выбора', style: theme.textTheme.titleLarge),
            DropdownButton<String>(
              isExpanded: true,
              value: selected?.name,
              onChanged: (name) {
                if (name != null) model.selectLegend(name);
              },
              items: [
                for (final pick in board.picks)
                  DropdownMenuItem(value: pick.name, child: Text(pick.name)),
              ],
            ),
            const SizedBox(height: 8),
            if (points.isEmpty)
              const Text('Дневная история для этой легенды сейчас недоступна.')
            else
              _TrendChart(points: points),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<PickPoint> points;

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${_percent(latest.percent)} · ${_date(latest.day)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (delta != null)
              Text(
                '${delta >= 0 ? '+' : '−'}${_number(delta.abs())} п. п. за 7 дней',
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 144,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(_percent(max)), Text(_percent(min))],
              ),
            ),
            Expanded(
              child: Semantics(
                label:
                    'Дневная доля выбора с ${_date(points.first.day)} по ${_date(latest.day)}',
                child: SizedBox(
                  height: 144,
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
    final start = points.first.day;
    final span = math.max(1, points.last.day.difference(start).inDays);
    Offset? previous;
    DateTime? previousDay;
    for (final point in points) {
      final x = size.width * point.day.difference(start).inDays / span;
      final y = size.height * (max - point.percent) / (max - min);
      final position = Offset(x, y);
      if (previous != null && point.day.difference(previousDay!).inDays == 1) {
        canvas.drawLine(previous, position, line);
      }
      canvas.drawCircle(position, 1.9, line);
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

String _number(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
String _percent(double value) => '${_number(value)}%';
