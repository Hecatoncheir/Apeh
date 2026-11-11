import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'builds/build_guides.dart';
import 'builds/builds_page.dart';
import 'builds/builds_view_model.dart';
import 'builds/guide_repository.dart';
import 'builds/upgrade_repository.dart';
import 'legends/legend_repository.dart';
import 'legends/legends_page.dart';
import 'legends/legends_view_model.dart';
import 'rotation/rotation_notifications.dart';
import 'rotation/rotation_page.dart';
import 'rotation/rotation_reminders.dart';
import 'rotation/rotation_repository.dart';
import 'rotation/rotation_storage.dart';
import 'rotation/rotation_view_model.dart';
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

class _ApehAppState extends State<ApehApp> {
  late final _client = widget.client ?? http.Client();
  int _tab = 0;
  LegendsViewModel? _legends;
  WeaponsViewModel? _weapons;
  BuildsViewModel? _builds;
  final _rotationStorage = RotationStorage();
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
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apeh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111419),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF825C),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            RotationPage(model: _model),
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
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 60,
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() {
            if (index == 1 && !kIsWeb) {
              _legends ??= LegendsViewModel(LegendRepository(_client));
              _legends?.refreshIfNeeded();
            }
            if (index == 2) {
              _openWeapons();
            }
            if (index == 3) {
              _builds ??= BuildsViewModel(
                UpgradeRepository(_client),
                GuideRepository(_client),
                online: !kIsWeb,
              );
            }
            _tab = index;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Карты',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Легенды',
            ),
            NavigationDestination(
              icon: Icon(Icons.compare_arrows_outlined),
              label: 'Оружие',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              label: 'Сборки',
            ),
          ],
        ),
      ),
    );
  }
}
