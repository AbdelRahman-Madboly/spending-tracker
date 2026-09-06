import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/spending_repository.dart';

class StatisticsScreen extends StatelessWidget {
  final SpendingRepository repository;

  const StatisticsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: FutureBuilder<Map<String, int>>(
        future: repository.spendByCategoryForPeriod(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final rows = data.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            children: [
              for (final row in rows)
                ListTile(
                  title: Text(row.key, style: AppText.body),
                  trailing: Text(formatPiastres(row.value), style: AppText.body),
                ),
            ],
          );
        },
      ),
    );
  }
}
