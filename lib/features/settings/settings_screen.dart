import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/category_strip.dart' show iconForName;
import '../add/widgets/new_item_dialog.dart' show showEditItemDialog;

/// App name shown in the "about" block and used as the Android launcher
/// label — kept as one constant so the two never drift apart.
const appName = 'مصاريفي';

/// App version shown in the "about" block. Mirrors `pubspec.yaml`'s
/// `version:` field; there is no `package_info_plus` dependency available
/// to read it at runtime (only one new dependency is permitted for this
/// task, spent on `flutter_launcher_icons`), so it is kept in sync by hand.
const appVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  final SpendingRepository repository;

  const SettingsScreen({super.key, required this.repository});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _salaryController = TextEditingController();
  List<CategoryView> _categories = const [];
  List<QuickPickItem> _items = const [];
  bool _loaded = false;
  String? _salaryError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final summary = await widget.repository.watchCurrentPeriod().first;
    final categories = await widget.repository.categories();
    final items = await widget.repository.allItems();
    if (!mounted) return;
    setState(() {
      _salaryController.text = formatPiastres(summary.salaryPiastres);
      _categories = categories;
      _items = items;
      _loaded = true;
    });
  }

  Future<void> _saveSalary() async {
    final parsed = parsePiastres(_salaryController.text);
    if (parsed == null) {
      setState(() => _salaryError = 'قيمة غير صحيحة');
      return;
    }
    setState(() => _salaryError = null);
    await widget.repository.updateSalary(parsed);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الراتب')),
      );
    }
  }

  Future<void> _archiveItem(String itemId) async {
    await widget.repository.archiveItem(itemId);
    await _load();
  }

  Future<void> _editItem(QuickPickItem item) async {
    final result = await showEditItemDialog(
      context: context,
      categories: _categories,
      item: item,
    );
    if (result == null) return;
    await widget.repository.updateItem(
      itemId: item.id,
      nameAr: result.nameAr,
      categoryKey: result.categoryKey,
      defaultAmountPiastres: result.amountPiastres,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('الإعدادات')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const _SectionHeader('الراتب'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('settings-salary-field'),
                          controller: _salaryController,
                          textDirection: TextDirection.rtl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'الراتب (جنيه)',
                            errorText: _salaryError,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        key: const Key('settings-salary-save'),
                        onPressed: _saveSalary,
                        child: const Text('حفظ'),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                  child: Text(
                    'حفظ الراتب يسجل فترة راتب جديدة بتاريخ اليوم، ولا يغيّر سجل الرواتب السابقة.',
                    style: AppText.caption,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('الأقسام'),
                for (final category in _categories)
                  ListTile(
                    key: ValueKey('settings-category-${category.key}'),
                    leading: Icon(iconForName(category.iconName),
                        color: AppColors.accent),
                    title: Text(category.labelAr, style: AppText.body),
                  ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('المنتجات'),
                for (final item in _items)
                  ListTile(
                    key: ValueKey('settings-item-${item.id}'),
                    onTap: () => _editItem(item),
                    title: Text(item.nameAr, style: AppText.body),
                    subtitle: Text(
                      _categories
                          .firstWhere(
                            (c) => c.key == item.categoryKey,
                            orElse: () => CategoryView(
                                key: item.categoryKey,
                                labelAr: item.categoryKey,
                                iconName: ''),
                          )
                          .labelAr,
                      style: AppText.caption,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.defaultAmountPiastres != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                                end: AppSpacing.sm),
                            child: Text(
                                formatPiastres(item.defaultAmountPiastres!),
                                style: AppText.body),
                          ),
                        IconButton(
                          key: ValueKey('archive-item-${item.id}'),
                          icon: const Icon(Icons.archive_outlined),
                          tooltip: 'أرشفة',
                          onPressed: () => _archiveItem(item.id),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('عن التطبيق'),
                const ListTile(
                  key: Key('settings-about'),
                  title: Text(appName, style: AppText.body),
                  subtitle: Text('الإصدار $appVersion', style: AppText.caption),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(title, style: AppText.title),
      ),
    );
  }
}
