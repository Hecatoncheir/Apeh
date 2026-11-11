import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const paper = Color(0xFFF6F3E9);
const surface = Color(0xFFFFFCF4);
const ink = Color(0xFF171814);
const muted = Color(0xFF626252);
const line = Color(0xFFD8D4C5);
const accent = Color(0xFFEDFC55);
const tint = Color(0xFFF2EFE5);
const selectedTint = Color(0xFFF3F8C6);
const positive = Color(0xFF3E643A);
const negative = Color(0xFFA0382C);
const panelRadius = BorderRadius.all(Radius.circular(18));

const mono = TextStyle(fontFamily: 'JetBrains Mono');

extension ApehColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => colors.brightness == Brightness.dark;
  Color get sheet => Theme.of(this).scaffoldBackgroundColor;
  Color get subtleFill => isDark ? const Color(0xFF292A23) : tint;
  Color get positiveText => isDark ? const Color(0xFFAFD8A4) : positive;
  Color get negativeText => isDark ? const Color(0xFFFFA899) : negative;
}

TextStyle display(double size, {double weight = 900}) => TextStyle(
  color: ink,
  fontFamily: 'Nunito',
  fontSize: size,
  height: 1.08,
  letterSpacing: -size * .04,
  fontVariations: [FontVariation.weight(weight)],
);

ThemeData apehTheme({bool dark = false}) {
  const lightColors = ColorScheme.light(
    primary: ink,
    onPrimary: surface,
    primaryContainer: accent,
    onPrimaryContainer: ink,
    secondary: muted,
    onSecondary: surface,
    secondaryContainer: selectedTint,
    onSecondaryContainer: ink,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: muted,
    outlineVariant: line,
    error: negative,
  );
  const darkColors = ColorScheme.dark(
    primary: accent,
    onPrimary: ink,
    primaryContainer: accent,
    onPrimaryContainer: ink,
    secondary: Color(0xFFC2BFAE),
    onSecondary: ink,
    secondaryContainer: Color(0xFF414521),
    onSecondaryContainer: Color(0xFFF7F4E8),
    surface: Color(0xFF22231D),
    onSurface: Color(0xFFF7F4E8),
    onSurfaceVariant: Color(0xFFC2BFAE),
    outline: Color(0xFF989581),
    outlineVariant: Color(0xFF424337),
    error: Color(0xFFFFA899),
  );
  final colors = dark ? darkColors : lightColors;
  final base = ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: dark ? const Color(0xFF191A16) : paper,
    fontFamily: 'Nunito Sans',
    dividerColor: colors.outlineVariant,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: display(
        44,
        weight: 1000,
      ).copyWith(color: colors.onSurface),
      headlineSmall: display(25).copyWith(color: colors.onSurface),
      titleLarge: display(24).copyWith(color: colors.onSurface),
      titleMedium: display(17, weight: 800).copyWith(color: colors.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: panelRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: accent,
      secondarySelectedColor: accent,
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? ink : colors.onSurface,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: ink,
        side: const BorderSide(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.outlineVariant,
    ),
  );
}

class ApehIcon extends StatelessWidget {
  const ApehIcon(this.name, {super.key, this.size = 20, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/interface/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? context.colors.onSurface,
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}

class ApehBrand extends StatelessWidget {
  const ApehBrand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Apeh',
    image: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'site/assets/apeh-mark.svg',
          width: 42,
          height: 42,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 10),
        SvgPicture.asset(
          'site/assets/apeh-logo.svg',
          width: 82,
          height: 34,
          colorFilter: context.isDark
              ? ColorFilter.mode(context.colors.onSurface, BlendMode.srcIn)
              : null,
          excludeFromSemantics: true,
        ),
      ],
    ),
  );
}

class ApehPage extends StatelessWidget {
  const ApehPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.actions = const [],
    this.body,
  });

  final String title;
  final String description;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final padding = EdgeInsets.fromLTRB(
          compact ? 14 : 32,
          18,
          compact ? 14 : 32,
          24,
        );
        final content = [
          _header(context, compact),
          const SizedBox(height: 16),
          ...children,
        ];
        final pane = body;
        final minimumHeight = compact ? 660.0 : 450.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: pane != null && constraints.maxHeight >= minimumHeight
                ? Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...content,
                        Expanded(child: pane),
                      ],
                    ),
                  )
                : ListView(
                    primary: false,
                    padding: padding,
                    children: [
                      ...content,
                      if (pane != null)
                        SizedBox(height: compact ? 475 : 315, child: pane),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool compact) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 8,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: display(
                compact ? 34 : 52,
                weight: 1000,
              ).copyWith(color: context.colors.onSurface),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description,
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      if (actions.isNotEmpty)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
    ],
  );
}

class ApehColumns extends StatelessWidget {
  const ApehColumns({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 680,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });

  final Widget first;
  final Widget second;
  final double breakpoint;
  final int firstFlex;
  final int secondFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 14), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: firstFlex, child: first),
          const SizedBox(width: 14),
          Expanded(flex: secondFlex, child: second),
        ],
      );
    },
  );
}

class ApehPanel extends StatelessWidget {
  const ApehPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class ApehSelect<T> extends StatelessWidget {
  const ApehSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelFor,
  });

  final String label;
  final T? value;
  final Iterable<T> items;
  final ValueChanged<T>? onChanged;
  final String Function(T)? labelFor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      InputDecorator(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: onChanged == null
                ? null
                : (item) {
                    if (item != null) onChanged!(item);
                  },
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item,
                  child: Text(
                    labelFor?.call(item) ?? item.toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
