import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'app_shell.dart';
import 'builds/builds_cubit.dart';
import 'builds/guide_repository.dart';
import 'builds/upgrade_repository.dart';
import 'design/apeh_design.dart';
import 'l10n/generated/app_localizations.dart';
import 'legends/legend_repository.dart';
import 'legends/legends_cubit.dart';
import 'rotation/rotation_cubit.dart';
import 'rotation/rotation_notifications.dart';
import 'rotation/rotation_reminders.dart';
import 'rotation/rotation_repository.dart';
import 'rotation/rotation_storage.dart';
import 'settings/appearance_cubit.dart';
import 'settings/appearance_settings.dart';
import 'weapons/weapon_repository.dart';
import 'weapons/weapons_cubit.dart';

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

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AppearanceCubit()),
      BlocProvider(create: (_) => _rotation()),
      BlocProvider(create: (_) => LegendsCubit(LegendRepository(_client))),
      BlocProvider(create: (_) => WeaponsCubit(WeaponRepository(_client))),
      BlocProvider(
        create: (_) => BuildsCubit(
          UpgradeRepository(_client),
          GuideRepository(_client),
          online: !kIsWeb,
        ),
      ),
    ],
    child: _AppView(client: _client),
  );

  RotationCubit _rotation() {
    final storage = RotationStorage();
    return RotationCubit(
      RotationRepository(RotationApi(_client)),
      storage,
      canLoad: !kIsWeb,
      reminders: LocalRotationNotifications.supported
          ? RotationReminders(
              storage,
              widget.notifications ?? LocalRotationNotifications(),
            )
          : null,
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView({required this.client});

  final http.Client client;

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _updateReminderLanguage(
    context.read<AppearanceCubit>().state.settings.language,
  );

  void _updateReminderLanguage(AppLanguage language) {
    final locale =
        language.locale ??
        basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        );
    context.read<RotationCubit>().reminders?.setEnglish(
      locale.languageCode == 'en',
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AppearanceCubit, AppearanceState>(
        listenWhen: (previous, current) =>
            previous.ready != current.ready ||
            previous.settings.language != current.settings.language,
        listener: (_, state) =>
            _updateReminderLanguage(state.settings.language),
        child:
            BlocSelector<AppearanceCubit, AppearanceState, AppearanceSettings>(
              selector: (state) => state.settings,
              builder: (context, settings) => MaterialApp(
                title: 'Apeh',
                debugShowCheckedModeBanner: false,
                locale: settings.language.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: apehTheme(),
                darkTheme: apehTheme(dark: true),
                themeMode: settings.theme,
                builder: (context, child) =>
                    ApehScale(percent: settings.scale, child: child!),
                home: ApehShell(client: widget.client),
              ),
            ),
      );
}
