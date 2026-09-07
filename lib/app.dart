import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/design/tokens.dart';
import 'data/db/database.dart';
import 'data/drift_spending_repository.dart';
import 'features/home/home_screen.dart';

/// The app's [ThemeData]. Every button style sets a 48dp-tall minimum tap
/// target at the theme level — not per-button — so any `FilledButton`,
/// `OutlinedButton` or `TextButton` added anywhere in the app clears the
/// floor automatically, rather than relying on each call site to remember a
/// `style:` override.
///
/// The [ColorScheme] is built explicitly from [AppColors] rather than left
/// at Material 3's stock purple defaults — without this, buttons and
/// AppBars render with Flutter's default seed colour instead of the app's
/// own palette, regardless of what individual widgets pass as their own
/// `color:`/`backgroundColor:`.
ThemeData buildAppTheme() {
  const minimumTapTarget = Size(64, 48);
  const colorScheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.negative,
    onError: Colors.white,
  );
  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      // Without this, Material 3 tints the AppBar with a translucent wash
      // of the colour scheme's primary whenever content scrolls under it —
      // the "M3 surface tint" this fix removes.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    fontFamily: 'IBMPlexSansArabic',
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: minimumTapTarget),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: minimumTapTarget),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: minimumTapTarget),
    ),
  );
}

class SpendingApp extends StatefulWidget {
  const SpendingApp({super.key});

  @override
  State<SpendingApp> createState() => _SpendingAppState();
}

class _SpendingAppState extends State<SpendingApp> {
  late final AppDatabase _database;
  late final DriftSpendingRepository _repository;

  @override
  void initState() {
    super.initState();
    // Real-data seeding happens inside AppDatabase's own onCreate (see
    // lib/data/db/database.dart) — before this constructor returns, drift
    // has already guaranteed no query run against _database can observe
    // an unseeded database, so there is nothing to await here.
    _database = AppDatabase();
    _repository = DriftSpendingRepository(_database);
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeScreen(repository: _repository),
    );
  }
}
