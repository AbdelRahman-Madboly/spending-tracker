import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/category_colors.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';

typedef _CategoryBreakdown = ({
  Map<String, int> byCategory,
  List<CategoryView> categories,
});

class StatisticsScreen extends StatelessWidget {
  final SpendingRepository repository;

  const StatisticsScreen({super.key, required this.repository});

  Future<_CategoryBreakdown> _load() async {
    final byCategory = await repository.spendByCategoryForPeriod();
    final categories = await repository.categories();
    return (byCategory: byCategory, categories: categories);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: FutureBuilder<_CategoryBreakdown>(
        future: _load(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final labelsByKey = {
            for (final c in data.categories) c.key: c,
          };
          final rows = data.byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final total = rows.fold<int>(0, (sum, r) => sum + r.value);
          // A category's colour belongs to its row (colorKey), so it is the
          // same on every screen and in every period, whatever its rank.
          Color inkOf(String key) =>
              palette.categoryInk(labelsByKey[key]?.colorKey ?? '');

          return ListView(
            children: [
              if (rows.isNotEmpty && total > 0)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          for (final row in rows)
                            PieChartSectionData(
                              value: row.value.toDouble(),
                              color: inkOf(row.key),
                              title: '',
                              radius: 48,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              for (final row in rows)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: palette.categoryInkFill(
                        labelsByKey[row.key]?.colorKey ?? ''),
                    child: Icon(
                      iconFor(labelsByKey[row.key]?.iconName ?? ''),
                      color: inkOf(row.key),
                    ),
                  ),
                  title: Text(
                    labelsByKey[row.key]?.labelAr ?? row.key,
                    style: AppText.body,
                  ),
                  trailing:
                      Text(formatPiastres(row.value), style: AppText.body),
                ),
            ],
          );
        },
      ),
    );
  }
}
