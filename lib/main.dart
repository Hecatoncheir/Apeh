import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'builds/build_guides.dart';
import 'builds/builds_page.dart';
import 'builds/builds_view_model.dart';
import 'builds/guide_repository.dart';
import 'builds/upgrade_repository.dart';
import 'design/apeh_design.dart';
import 'legends/legend_repository.dart';
import 'legends/legends_page.dart';
import 'legends/legends_view_model.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/localization.dart';
import 'rotation/rotation_notifications.dart';
import 'rotation/rotation_page.dart';
import 'rotation/rotation_reminders.dart';
import 'rotation/rotation_repository.dart';
import 'rotation/rotation_storage.dart';
import 'rotation/rotation_view_model.dart';
import 'settings/appearance_settings.dart';
import 'settings/settings_page.dart';
import 'updates/windows_update_button.dart';
import 'weapons/weapon_repository.dart';
import 'weapons/weapons_page.dart';
import 'weapons/weapons_view_model.dart';

void main() => runApp(const ApehApp());

class ApehApp extends StatefulWidget {
  const ApehApp({super.key, this.client, this.notifications});

  final http.Client? client;
  final RotationNotifications? notifications;

  @override
  State<ApehApp> createState() => _ApehAppState();
}

class _ApehAppState extends State<ApehApp> with WidgetsBindingObserver {
  late final _client = widget.client ?? http.Client();
  int _tab = 0;
  LegendsViewModel? _legends;
  WeaponsViewModel? _weapons;
  BuildsViewModel? _builds;
  final _rotationStorage = RotationStorage();
  AppearanceSettings _appearance = const AppearanceSettings();
  bool _appearanceReady = false;
  Future<bool> _appearanceWrite = Future.value(true);
  late final _model = RotationViewModel(
    RotationRepository(RotationApi(_client)),
    _rotationStorage,
    canLoad: !kIsWeb,
    reminders: LocalRotationNotifications.supported
        ? RotationReminders(
            _rotationStorage,
            widget.notifications ?? LocalRotationNotifications(),
          )
        : null,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreAppearance();
  }

  Future<void> _restoreAppearance() async {
    try {
      final saved = await AppearanceSettings.load();
      if (mounted) {
        setState(() => _appearance = saved);
        _updateReminderLanguage();
      }
    } on Exception {
      // При сбое чтения доступны настройки по умолчанию.
    } finally {
      if (mounted) setState(() => _appearanceReady = true);
    }
  }

  Future<bool> _changeAppearance(
    Future<bool> Function() save,
    AppearanceSettings Function(AppearanceSettings) update,
  ) {
    _appearanceWrite = _appearanceWrite.then((_) async {
      try {
        if (!await save()) return false;
        if (mounted) {
          setState(() => _appearance = update(_appearance));
          _updateReminderLanguage();
        }
        return true;
      } on Exception {
        return false;
      }
    });
    return _appearanceWrite;
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _updateReminderLanguage();

  void _updateReminderLanguage() {
    final locale =
        _appearance.language.locale ??
        basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        );
    _model.reminders?.setEnglish(locale.languageCode == 'en');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.dispose();
    _legends?.dispose();
    _weapons?.dispose();
    _builds?.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  WeaponsViewModel _openWeapons() =>
      _weapons ??= WeaponsViewModel(WeaponRepository(_client));

  void _comparePair(WeaponPair pair) {
    setState(() {
      _openWeapons().selectPair(pair.first, pair.second);
      _tab = 2;
    });
  }

  void _selectTab(int index) {
    setState(() {
      if (index == 1 && !kIsWeb) {
        _legends ??= LegendsViewModel(LegendRepository(_client));
        _legends?.refreshIfNeeded();
      }
      if (index == 2) _openWeapons();
      if (index == 3) {
        _builds ??= BuildsViewModel(
          UpgradeRepository(_client),
          GuideRepository(_client),
          online: !kIsWeb,
        );
      }
      _tab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apeh',
      debugShowCheckedModeBanner: false,
      locale: _appearance.language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: apehTheme(),
      darkTheme: apehTheme(dark: true),
      themeMode: _appearance.theme,
      builder: (context, child) =>
          ApehScale(percent: _appearance.scale, child: child!),
      home: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                children: [
                  _Navigation(
                    wide: wide,
                    selected: _tab,
                    onSelected: _selectTab,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      sizing: StackFit.expand,
                      children: [
                        RotationPage(
                          model: _model,
                          updateAction: WindowsUpdateButton(client: _client),
                        ),
                        if (_tab == 1 || _legends != null)
                          LegendsPage(model: _legends)
                        else
                          const SizedBox.shrink(),
                        if (_weapons case final model?)
                          WeaponsPage(model: model)
                        else
                          const SizedBox.shrink(),
                        if (_builds case final model?)
                          BuildsPage(model: model, onCompare: _comparePair)
                        else
                          const SizedBox.shrink(),
                        SettingsPage(
                          appearance: _appearance,
                          ready: _appearanceReady,
                          onLanguage: (value) => _changeAppearance(
                            () => AppearanceSettings.saveLanguage(value),
                            (settings) => settings.copyWith(language: value),
                          ),
                          onTheme: (value) => _changeAppearance(
                            () => AppearanceSettings.saveTheme(value),
                            (settings) => settings.copyWith(theme: value),
                          ),
                          onScale: (value) => _changeAppearance(
                            () => AppearanceSettings.saveScale(value),
                            (settings) => settings.copyWith(scale: value),
                          ),
                          client: _client,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: selected ? ink : Colors.transparent),
    );
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
            style: TextButton.styleFrom(
              shape: shape,
              side: BorderSide(color: selected ? ink : Colors.transparent),
              backgroundColor: selected ? accent : context.sheet,
              foregroundColor: selected ? ink : context.colors.onSurface,
              alignment: wide ? Alignment.centerLeft : Alignment.center,
              minimumSize: Size(wide ? double.infinity : 0, 44),
              padding: EdgeInsets.symmetric(horizontal: wide ? 11 : 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              mainAxisSize: MainAxisSize.min,
              spacing: wide ? 10 : 2,
              children: [
                ApehIcon(
                  icon,
                  size: wide ? 20 : 16,
                  color: selected ? ink : context.colors.onSurface,
                ),
                if (wide) Flexible(child: caption) else caption,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
