import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import 'widgets/month_comparison_card.dart';
import 'widgets/monthly_bar_chart.dart';
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
          IconButton(
            key: const Key('settings-button'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(repository: repository),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        // A CustomScrollView (rather than a fixed Column+Expanded) so the
        // period card, month comparison, chart and today's entries all
        // scroll together — the added month-stats content pushes the
        // total height past a Column's available space on real phones.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: StreamBuilder<PeriodSummary>(
                stream: repository.watchCurrentPeriod(),
                builder: (context, snapshot) {
                  final summary = snapshot.data;
                  if (summary == null) return const SizedBox(height: 200);
                  return PeriodSummaryCard(summary: summary);
                },
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(
              child: FutureBuilder<List<({String yearMonth, int totalPiastres})>>(
                future: repository.monthlyTotals(6),
                builder: (context, snapshot) {
                  final months = snapshot.data;
                  if (months == null || months.length < 2) {
                    return const SizedBox.shrink();
                  }
                  void openStatistics() => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              StatisticsScreen(repository: repository),
                        ),
                      );
                  return Column(
                    children: [
                      MonthComparisonCard(
                        thisMonthPiastres: months.last.totalPiastres,
                        lastMonthPiastres:
                            months[months.length - 2].totalPiastres,
                        onTap: openStatistics,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      MonthlyBarChart(months: months, onTap: openStatistics),
                    ],
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.md)),
            const SliverToBoxAdapter(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('النهاردة', style: AppText.title),
                ),
              ),
            ),
            StreamBuilder<List<EntryView>>(
              stream: repository.watchEntriesForDay(DateTime(2026, 9, 6)),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <EntryView>[];
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 88),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ListTile(
                        title: Text(entries[i].displayName,
                            style: AppText.body),
                        trailing: Text(
                            formatPiastres(entries[i].amountPiastres),
                            style: AppText.body),
                      ),
                      childCount: entries.length,
                    ),
                  ),
                );
              },
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
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
