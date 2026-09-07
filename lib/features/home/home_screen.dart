import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../add/widgets/category_strip.dart' show iconForName;
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import 'widgets/month_comparison_card.dart';
import 'widgets/period_summary_card.dart';
import 'widgets/range_chart_section.dart';

typedef _CategoryBreakdown = ({
  Map<String, int> byCategory,
  List<CategoryView> categories,
});

Future<_CategoryBreakdown> _loadCategoryBreakdown(
    SpendingRepository repository) async {
  final byCategory = await repository.spendByCategoryForPeriod();
  final categories = await repository.categories();
  return (byCategory: byCategory, categories: categories);
}

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
                      RangeChartSection(
                          repository: repository, onTap: openStatistics),
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
                  child: Text('الأقسام', style: AppText.title),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<_CategoryBreakdown>(
                future: _loadCategoryBreakdown(repository),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) return const SizedBox.shrink();
                  final labelsByKey = {
                    for (final c in data.categories) c.key: c,
                  };
                  final rows = data.byCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 88),
                    child: Column(
                      children: [
                        for (final row in rows)
                          ListTile(
                            leading: Icon(
                              iconForName(
                                  labelsByKey[row.key]?.iconName ?? ''),
                              color: AppColors.accent,
                            ),
                            title: Text(
                              labelsByKey[row.key]?.labelAr ?? row.key,
                              style: AppText.body,
                            ),
                            trailing: Text(formatPiastres(row.value),
                                style: AppText.body),
                          ),
                      ],
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
        // No explicit backgroundColor/foregroundColor here: the app theme's
        // ColorScheme (see buildAppTheme in app.dart) leaves
        // primaryContainer/onPrimaryContainer unset, so Flutter's default
        // FAB style falls back to colorScheme.primary/onPrimary — which are
        // AppColors.accent/white, the exact values this used to hard-code.
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
