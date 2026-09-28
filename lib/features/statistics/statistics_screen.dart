import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart';
import 'category_palette.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                              color: colorForCategory(row.key),
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
                    backgroundColor: colorForCategory(row.key).withValues(
                      alpha: 0.15,
                    ),
                    child: Icon(
                      iconForName(labelsByKey[row.key]?.iconName ?? ''),
                      color: colorForCategory(row.key),
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
