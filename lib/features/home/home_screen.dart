import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'widgets/period_summary_card.dart';

class HomeScreen extends StatelessWidget {
  final SpendingRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<PeriodSummary>(
              stream: repository.watchCurrentPeriod(),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                if (summary == null) return const SizedBox(height: 200);
                return PeriodSummaryCard(summary: summary);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('النهاردة', style: AppText.title),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<EntryView>>(
                stream: repository.watchEntriesForDay(DateTime(2026, 9, 6)),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? const <EntryView>[];
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(entries[i].displayName, style: AppText.body),
                      trailing: Text(formatPiastres(entries[i].amountPiastres),
                          style: AppText.body),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
