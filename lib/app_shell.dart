import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'builds/build_guides.dart';
import 'builds/builds_page.dart';
import 'design/apeh_design.dart';
import 'l10n/localization.dart';
import 'legends/legends_cubit.dart';
import 'legends/legends_page.dart';
import 'rotation/rotation_page.dart';
import 'settings/settings_page.dart';
import 'updates/windows_update_button.dart';
import 'weapons/weapons_cubit.dart';
import 'weapons/weapons_page.dart';

enum _Tab { maps, legends, weapons, builds, settings }

class ApehShell extends StatefulWidget {
  const ApehShell({super.key, required this.client});

  final http.Client client;

  @override
  State<ApehShell> createState() => _ApehShellState();
}

class _ApehShellState extends State<ApehShell> {
  final _visited = {_Tab.maps};
  _Tab _tab = _Tab.maps;

  void _select(_Tab tab) {
    if (tab == _Tab.legends && !kIsWeb) {
      context.read<LegendsCubit>().refreshIfNeeded();
    }
    setState(() {
      _visited.add(tab);
      _tab = tab;
    });
  }

  void _compare(WeaponPair pair) {
    context.read<WeaponsCubit>().selectPair(pair.first, pair.second);
    _select(_Tab.weapons);
  }

  Widget _page(_Tab tab) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    return switch (tab) {
      _Tab.maps => RotationPage(
        updateAction: WindowsUpdateButton(client: widget.client),
      ),
      _Tab.legends => const LegendsPage(),
      _Tab.weapons => const WeaponsPage(),
      _Tab.builds => BuildsPage(onCompare: _compare),
      _Tab.settings => SettingsPage(client: widget.client),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            children: [
              _Navigation(
                wide: wide,
                selected: _tab.index,
                onSelected: (index) => _select(_Tab.values[index]),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab.index,
                  sizing: StackFit.expand,
                  children: _Tab.values.map(_page).toList(),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.wide,
    required this.selected,
    required this.onSelected,
  });

  final bool wide;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final tabs = [
      (strings.maps, 'maps'),
      (strings.legends, 'legends'),
      (strings.weapons, 'weapons'),
      (strings.builds, 'builds'),
    ];
    final buttons = [
      for (final (index, (label, icon)) in tabs.indexed)
        _TabButton(
          label: label,
          icon: icon,
          selected: index == selected,
          wide: wide,
          onPressed: () => onSelected(index),
        ),
    ];
    final settings = _TabButton(
      label: strings.settings,
      icon: 'settings',
      selected: selected == tabs.length,
      wide: wide,
      onPressed: () => onSelected(tabs.length),
    );
    final border = BorderSide(color: context.colors.outlineVariant);
    return Container(
      width: wide ? 194 : double.infinity,
      height: wide ? double.infinity : null,
      decoration: BoxDecoration(
        border: wide ? Border(right: border) : Border(bottom: border),
      ),
      padding: EdgeInsets.fromLTRB(14, wide ? 22 : 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ApehBrand(),
                    const SizedBox(height: 26),
                    ...buttons,
                  ],
                ),
              ),
            )
          else ...[
            const ApehBrand(),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final button in [...buttons, settings])
                  Expanded(child: button),
              ],
            ),
          ],
          if (wide) settings,
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.wide,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final bool selected;
  final bool wide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: selected ? ink : Colors.transparent);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: border,
    );
    final foreground = selected ? ink : context.colors.onSurface;
    final caption = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: wide ? 15 : 12,
        fontVariations: const [FontVariation.weight(800)],
      ),
    );
    return Padding(
      padding: wide
          ? const EdgeInsets.only(bottom: 5)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        selected: selected,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            shadows: selected
                ? const [BoxShadow(color: ink, offset: Offset(1, 2))]
                : const [],
          ),
          child: TextButton(
            onPressed: onPressed,
            style: _style(context, shape, foreground),
            child: _content(caption, foreground),
          ),
        ),
      ),
    );
  }

  ButtonStyle _style(
    BuildContext context,
    RoundedRectangleBorder shape,
    Color foreground,
  ) {
    return TextButton.styleFrom(
      shape: shape,
      side: shape.side,
      backgroundColor: selected ? accent : context.sheet,
      foregroundColor: foreground,
      alignment: wide ? Alignment.centerLeft : Alignment.center,
      minimumSize: Size(wide ? double.infinity : 0, 44),
      padding: EdgeInsets.symmetric(horizontal: wide ? 11 : 2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _content(Widget caption, Color foreground) {
    final symbol = ApehIcon(icon, size: wide ? 20 : 16, color: foreground);
    if (wide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          symbol,
          Flexible(child: caption),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [symbol, caption],
    );
  }
}
