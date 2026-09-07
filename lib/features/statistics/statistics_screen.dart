import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart';

typedef _CategoryBreakdown = ({
  Map<String, int> byCategory,
  List<CategoryView> categories,
});

class StatisticsScreen extends StatelessWidget {
  final SpendingRepository repository;

  const StatisticsScreen({super.key, required this.repository});

  /// A fixed, distinguishable colour per pie slice / legend row. Kept
  /// independent of category identity (there are ten categories but no
  /// per-category colour in the design tokens) so the same category always
  /// gets the same colour within one render, cycling only past ten.
  static const _sliceColors = [
    AppColors.accent,
    AppColors.positive,
    AppColors.negative,
    Color(0xFFE8A33D),
    Color(0xFF8E5FD9),
    Color(0xFF2FA9B0),
    Color(0xFFD46FA6),
    Color(0xFF6B8E23),
    Color(0xFFB0523B),
    Color(0xFF4C6B9A),
  ];

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
                          for (var i = 0; i < rows.length; i++)
                            PieChartSectionData(
                              value: rows[i].value.toDouble(),
                              color: _sliceColors[i % _sliceColors.length],
                              title: '',
                              radius: 48,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < rows.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _sliceColors[i % _sliceColors.length]
                            .withOpacity(0.15),
                    child: Icon(
                      iconForName(labelsByKey[rows[i].key]?.iconName ?? ''),
                      color: _sliceColors[i % _sliceColors.length],
                    ),
                  ),
                  title: Text(
                    labelsByKey[rows[i].key]?.labelAr ?? rows[i].key,
                    style: AppText.body,
                  ),
                  trailing:
                      Text(formatPiastres(rows[i].value), style: AppText.body),
                ),
            ],
          );
        },
      ),
    );
  }
}
