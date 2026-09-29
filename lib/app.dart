import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'core/design/app_theme.dart';
import 'data/bill_reminders.dart';
import 'data/backup/data_transfer.dart';
import 'data/db/database.dart';
import 'data/drift_spending_repository.dart';
import 'data/import_sources.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/quick_launch.dart';

class SpendingApp extends StatefulWidget {
  const SpendingApp({
    super.key,
    this.openDatabase = AppDatabase.new,
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  /// Opens the database, at start and again after a restore.
  final AppDatabase Function() openDatabase;

  /// Where the database file, attachments and backups live.
  final Future<Directory> Function() documentsDirectory;

  @override
  State<SpendingApp> createState() => _SpendingAppState();
}

class _SpendingAppState extends State<SpendingApp>
    with WidgetsBindingObserver
    implements DatabaseHost {
  late AppDatabase _database;
  late DriftSpendingRepository _repository;
  late ThemeModeController _themeMode;

  /// True while a restore has the database closed: no screen may read it.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Bill reminders are also put back on every return to the app (a bill
    // made from an entry, a day that passed).
    WidgetsBinding.instance.addObserver(this);
    _open(ThemeMode.system);
  }

  /// Real-data seeding happens inside AppDatabase's own onCreate (see
  /// lib/data/db/database.dart) — before this constructor returns, drift
  /// has already guaranteed no query run against _database can observe
  /// an unseeded database, so there is nothing to await here.
  void _open(ThemeMode initialTheme) {
    _database = widget.openDatabase();
    _repository = DriftSpendingRepository(_database);
    // Starts on [initialTheme] and switches once the stored choice is
    // read, one frame in; a failed read leaves it where it started.
    _themeMode = ThemeModeController(_repository)..value = initialTheme;
    _themeMode.load().catchError((Object _) {});
    // Bill reminders follow the bills: put back on every start and every
    // return to the app (a bill made from an entry, a day that passed).
    // A reboot is covered by the plugin's own boot receiver.
    BillReminders.shared.rescheduleFrom(_repository);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // While a restore has the database closed there is nothing to read.
    if (state == AppLifecycleState.resumed && !_closed) {
      BillReminders.shared.rescheduleFrom(_repository);
    }
  }

  @override
  AppDatabase get database => _database;

  @override
  Future<Directory> documentsDirectory() => widget.documentsDirectory();

  @override
  Future<void> reopenAfter(Future<void> Function() whileClosed) async {
    // Take every screen off the old database first, so none of them is
    // still listening when it closes.
    setState(() => _closed = true);
    await WidgetsBinding.instance.endOfFrame;
    final oldTheme = _themeMode;
    try {
      await _database.close();
      await whileClosed();
    } finally {
      _open(oldTheme.value);
      if (mounted) setState(() => _closed = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => oldTheme.dispose());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeMode.dispose();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DatabaseHostScope(
      host: this,
      child: ThemeModeScope(
        controller: _themeMode,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _themeMode,
          builder: (context, mode, _) => _buildApp(mode),
        ),
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
      home: _closed
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          // A new key per repository: a restore starts every screen afresh.
          : AppShell(
              key: ObjectKey(_repository),
              repository: _repository,
              shareInbox: PluginShareInbox(),
              quickActions: const PluginQuickActionsSource(),
            ),
    );
  }
}
