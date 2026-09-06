import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../statistics/statistics_screen.dart';
import 'widgets/period_summary_card.dart';

class HomeScreen extends StatelessWidget {
  final SpendingRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StatisticsScreen(repository: repository),
              ),
            ),
          ),
        ],
      ),
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
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddSheet(
            repository: repository,
            onSubmit: (draft) async {
              await repository.saveEntry(draft);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
