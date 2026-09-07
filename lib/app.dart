import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/db/database.dart';
import 'data/drift_spending_repository.dart';
import 'features/home/home_screen.dart';

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
      theme: ThemeData(fontFamily: 'IBMPlexSansArabic'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeScreen(repository: _repository),
    );
  }
}
