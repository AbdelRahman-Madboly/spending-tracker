import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/design/app_theme.dart';
import 'data/db/database.dart';
import 'data/drift_spending_repository.dart';
import 'features/shell/app_shell.dart';

class SpendingApp extends StatefulWidget {
  const SpendingApp({super.key});

  @override
  State<SpendingApp> createState() => _SpendingAppState();
}

class _SpendingAppState extends State<SpendingApp> {
  late final AppDatabase _database;
  late final DriftSpendingRepository _repository;
  late final ThemeModeController _themeMode;

  @override
  void initState() {
    super.initState();
    // Real-data seeding happens inside AppDatabase's own onCreate (see
    // lib/data/db/database.dart) — before this constructor returns, drift
    // has already guaranteed no query run against _database can observe
    // an unseeded database, so there is nothing to await here.
    _database = AppDatabase();
    _repository = DriftSpendingRepository(_database);
    // Starts on "follow the system" and switches once the stored choice is
    // read, one frame in; a failed read leaves it following the system.
    _themeMode = ThemeModeController(_repository);
    _themeMode.load().catchError((Object _) {});
  }

  @override
  void dispose() {
    _themeMode.dispose();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      controller: _themeMode,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeMode,
        builder: (context, mode, _) => _buildApp(mode),
      ),
    );
  }

  Widget _buildApp(ThemeMode mode) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppShell(repository: _repository),
    );
  }
}
