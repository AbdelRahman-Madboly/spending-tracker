import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/category_colors.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../data/gemini_key_store.dart';
import '../../data/import_sources.dart';
import '../../data/net/gemini_client.dart';
import '../../data/net/network_gate.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import '../add/widgets/new_item_dialog.dart'
    show showEditItemDialog, showNewItemDialog;
import 'import_screen.dart';
import 'widgets/category_dialogs.dart';
import 'recurring_bills_screen.dart';
import 'widgets/online_settings_section.dart';

/// App name shown in the "about" block and used as the Android launcher
/// label — kept as one constant so the two never drift apart.
const appName = 'مصاريفي';

/// App version shown in the "about" block. Mirrors `pubspec.yaml`'s
/// `version:` field; there is no `package_info_plus` dependency available
/// to read it at runtime (only one new dependency is permitted for this
/// task, spent on `flutter_launcher_icons`), so it is kept in sync by hand.
const appVersion = '1.0.0';

/// Generates a fresh, permanent English key for a new category or
/// subcategory. Keys are the storage/export identity and are never shown to
/// the user, so there is no reason to make them type one — a timestamp is
/// unique enough for a single-user local catalogue that only ever grows a
/// few rows at a time.
String _generateKey(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

class SettingsScreen extends StatefulWidget {
  final SpendingRepository repository;

  /// Where the Gemini key is saved. Defaults to secure storage.
  final GeminiKeyStore? geminiKeyStore;

  /// Tests the key. Defaults to one through a [NetworkGate] of its own.
  final GeminiClient? gemini;

  const SettingsScreen({
    super.key,
    required this.repository,
    this.geminiKeyStore,
    this.gemini,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _salaryController = TextEditingController();
  List<CategoryView> _categories = const [];
  Map<String, List<SubcategoryView>> _subcategoriesByCategory = const {};
  List<QuickPickItem> _items = const [];
  List<QuickPickItem> _archivedItems = const [];
  List<CategoryView> _archivedCategories = const [];
  List<SubcategoryView> _archivedSubcategories = const [];
  final Set<String> _expandedCategories = {};
  late final GeminiKeyStore _geminiKeys =
      widget.geminiKeyStore ?? SecureGeminiKeyStore();
  late final GeminiClient _gemini = widget.gemini ??
      GeminiClient(NetworkGate(widget.repository), widget.repository,
          _geminiKeys);
  bool _showArchivedItems = false;
  bool _loaded = false;
  String? _salaryError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => ImportScreen(
        repository: widget.repository,
        importer: appImporter(widget.repository),
        loadBundled: loadBundledPacks,
        pickFile: pickImportFile,
      ),
    ));
    // New categories may have come with the import.
    if (mounted) await _load();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  List<SubcategoryView> get _allSubcategories =>
      _subcategoriesByCategory.values.expand((s) => s).toList();

  Future<void> _load() async {
    final summary = await widget.repository.watchCurrentPeriod().first;
    final categories = await widget.repository.categories();
    final items = await widget.repository.allItems();
    final archivedItems = await widget.repository.archivedItems();
    final archivedCategories = await widget.repository.archivedCategories();
    final archivedSubcategories =
        await widget.repository.archivedSubcategories();
    final subcategoriesByCategory = <String, List<SubcategoryView>>{};
    for (final category in categories) {
      subcategoriesByCategory[category.key] =
          await widget.repository.subcategories(category.key);
    }
    if (!mounted) return;
    setState(() {
      _salaryController.text = formatPiastres(summary.salaryPiastres);
      _categories = categories;
      _subcategoriesByCategory = subcategoriesByCategory;
      _items = items;
      _archivedItems = archivedItems;
      _archivedCategories = archivedCategories;
      _archivedSubcategories = archivedSubcategories;
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

  Future<void> _unarchiveItem(String itemId) async {
    try {
      await widget.repository.unarchiveItem(itemId);
    } on DuplicateBarcodeException {
      // Another live item took this barcode while this one was archived;
      // bringing it back would make a scan ambiguous, so it stays put.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('الباركود مسجل لصنف آخر، فلا يمكن استرجاع هذا الصنف')));
      }
      return;
    }
    await _load();
  }

  Future<void> _editItem(QuickPickItem item) async {
    final result = await showEditItemDialog(
      context: context,
      categories: _categories,
      item: item,
      subcategories: _allSubcategories,
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

  Future<void> _addItem() async {
    if (_categories.isEmpty) return;
    final result = await showNewItemDialog(
      context: context,
      categories: _categories,
      initialCategoryKey: _categories.first.key,
      subcategories: _allSubcategories,
    );
    if (result == null) return;
    await widget.repository.createItem(
      nameAr: result.nameAr,
      categoryKey: result.categoryKey,
      subcategoryKey: result.subcategoryKey,
      defaultAmountPiastres: result.amountPiastres,
    );
    await _load();
  }

  Future<void> _addCategory() async {
    final result = await showCategoryDialog(context: context);
    if (result == null) return;
    await widget.repository.createCategory(
      key: _generateKey('cat'),
      labelAr: result.labelAr,
      iconName: result.iconName,
      colorKey: result.colorKey,
    );
    await _load();
  }

  Future<void> _editCategory(CategoryView category) async {
    final result = await showCategoryDialog(
      context: context,
      initialLabelAr: category.labelAr,
      initialIconName: category.iconName,
      initialColorKey: category.colorKey,
    );
    if (result == null) return;
    await widget.repository.updateCategory(
      key: category.key,
      labelAr: result.labelAr,
      iconName: result.iconName,
      colorKey: result.colorKey,
    );
    await _load();
  }

  Future<void> _archiveCategory(CategoryView category) async {
    final subCount = _subcategoriesByCategory[category.key]?.length ?? 0;
    final itemCount =
        _items.where((i) => i.categoryKey == category.key).length;
    if (subCount > 0 || itemCount > 0) {
      final confirmed = await showArchiveCascadeConfirmationDialog(
        context: context,
        labelAr: category.labelAr,
        childrenSummary: '$subCount فئة فرعية و $itemCount منتج',
      );
      if (confirmed != true) return;
    }
    await widget.repository.archiveCategory(category.key);
    await _load();
  }

  Future<void> _unarchiveCategory(String key) async {
    await widget.repository.unarchiveCategory(key);
    await _load();
  }

  Future<void> _addSubcategory(String categoryKey) async {
    final result = await showSubcategoryDialog(
      context: context,
      categories: _categories,
      initialCategoryKey: categoryKey,
    );
    if (result == null) return;
    await widget.repository.createSubcategory(
      key: _generateKey('sub'),
      categoryKey: result.categoryKey,
      labelAr: result.labelAr,
      iconName: result.iconName,
    );
    await _load();
  }

  Future<void> _editSubcategory(SubcategoryView subcategory) async {
    final result = await showSubcategoryDialog(
      context: context,
      categories: _categories,
      initialCategoryKey: subcategory.categoryKey,
      initialLabelAr: subcategory.labelAr,
      initialIconName: subcategory.iconName,
    );
    if (result == null) return;
    await widget.repository.updateSubcategory(
      key: subcategory.key,
      categoryKey: result.categoryKey,
      labelAr: result.labelAr,
      iconName: result.iconName,
    );
    await _load();
  }

  Future<void> _archiveSubcategory(SubcategoryView subcategory) async {
    final itemCount =
        _items.where((i) => i.subcategoryKey == subcategory.key).length;
    if (itemCount > 0) {
      final confirmed = await showArchiveCascadeConfirmationDialog(
        context: context,
        labelAr: subcategory.labelAr,
        childrenSummary: '$itemCount منتج',
      );
      if (confirmed != true) return;
    }
    await widget.repository.archiveSubcategory(subcategory.key);
    await _load();
  }

  Future<void> _unarchiveSubcategory(String key) async {
    await widget.repository.unarchiveSubcategory(key);
    await _load();
  }

  void _toggleExpanded(String categoryKey) {
    setState(() {
      if (!_expandedCategories.remove(categoryKey)) {
        _expandedCategories.add(categoryKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
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
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                  child: Text(
                    'حفظ الراتب يسجل فترة راتب جديدة بتاريخ اليوم، ولا يغيّر سجل الرواتب السابقة.',
                    style: AppText.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                _SectionHeader(
                  'الأقسام',
                  trailing: IconButton(
                    key: const Key('add-category'),
                    icon: const Icon(AppIcons.addCircle),
                    tooltip: 'إضافة قسم',
                    onPressed: _addCategory,
                  ),
                ),
                for (final category in _categories) ...[
                  ListTile(
                    key: ValueKey('settings-category-${category.key}'),
                    leading: Icon(iconFor(category.iconName),
                        color: palette.categoryInk(category.colorKey)),
                    title: Text(category.labelAr, style: AppText.body),
                    onTap: () => _editCategory(category),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('archive-category-${category.key}'),
                          icon: const Icon(AppIcons.archive),
                          tooltip: 'أرشفة',
                          onPressed: () => _archiveCategory(category),
                        ),
                        IconButton(
                          key: ValueKey('expand-category-${category.key}'),
                          icon: Icon(
                            _expandedCategories.contains(category.key)
                                ? AppIcons.expandLess
                                : AppIcons.expandMore,
                          ),
                          tooltip: 'عرض الفئات الفرعية',
                          onPressed: () => _toggleExpanded(category.key),
                        ),
                      ],
                    ),
                  ),
                  if (_expandedCategories.contains(category.key))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 32),
                      child: Column(
                        children: [
                          for (final subcategory
                              in _subcategoriesByCategory[category.key] ??
                                  const <SubcategoryView>[])
                            ListTile(
                              key: ValueKey(
                                  'settings-subcategory-${subcategory.key}'),
                              leading: Icon(iconFor(subcategory.iconName),
                                  color: palette.textSecondary),
                              title: Text(subcategory.labelAr,
                                  style: AppText.body),
                              onTap: () => _editSubcategory(subcategory),
                              trailing: IconButton(
                                key: ValueKey(
                                    'archive-subcategory-${subcategory.key}'),
                                icon: const Icon(AppIcons.archive),
                                tooltip: 'أرشفة',
                                onPressed: () =>
                                    _archiveSubcategory(subcategory),
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: ValueKey('add-subcategory-${category.key}'),
                              onPressed: () => _addSubcategory(category.key),
                              icon: const Icon(AppIcons.add),
                              label: const Text('إضافة فئة فرعية'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const Divider(height: AppSpacing.lg),
                _SectionHeader(
                  'المنتجات',
                  trailing: IconButton(
                    key: const Key('add-item'),
                    icon: const Icon(AppIcons.addCircle),
                    tooltip: 'إضافة منتج',
                    onPressed: _addItem,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('items-view-active'),
                          onPressed: () =>
                              setState(() => _showArchivedItems = false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _showArchivedItems
                                ? null
                                : palette.primaryContainer,
                          ),
                          child: const Text('النشطة'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('items-view-archived'),
                          onPressed: () =>
                              setState(() => _showArchivedItems = true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _showArchivedItems
                                ? palette.primaryContainer
                                : null,
                          ),
                          child: const Text('المؤرشفة'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_showArchivedItems)
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
                            icon: const Icon(AppIcons.archive),
                            tooltip: 'أرشفة',
                            onPressed: () => _archiveItem(item.id),
                          ),
                        ],
                      ),
                    )
                else
                  for (final item in _archivedItems)
                    ListTile(
                      key: ValueKey('settings-archived-item-${item.id}'),
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
                      trailing: IconButton(
                        key: ValueKey('unarchive-item-${item.id}'),
                        icon: const Icon(AppIcons.unarchive),
                        tooltip: 'استعادة',
                        onPressed: () => _unarchiveItem(item.id),
                      ),
                    ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('الأقسام والفئات الفرعية المؤرشفة'),
                if (_archivedCategories.isEmpty &&
                    _archivedSubcategories.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                    child: Text(
                      'لا يوجد أقسام أو فئات فرعية مؤرشفة.',
                      style: AppText.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                  ),
                for (final category in _archivedCategories)
                  ListTile(
                    key: ValueKey('settings-archived-category-${category.key}'),
                    leading: Icon(iconFor(category.iconName),
                        color: palette.textSecondary),
                    title: Text(category.labelAr, style: AppText.body),
                    trailing: IconButton(
                      key: ValueKey('unarchive-category-${category.key}'),
                      icon: const Icon(AppIcons.unarchive),
                      tooltip: 'استعادة',
                      onPressed: () => _unarchiveCategory(category.key),
                    ),
                  ),
                for (final subcategory in _archivedSubcategories)
                  ListTile(
                    key: ValueKey(
                        'settings-archived-subcategory-${subcategory.key}'),
                    leading: Icon(iconFor(subcategory.iconName),
                        color: palette.textSecondary),
                    title: Text(subcategory.labelAr, style: AppText.body),
                    subtitle: Text(
                      [..._categories, ..._archivedCategories]
                          .firstWhere(
                            (c) => c.key == subcategory.categoryKey,
                            orElse: () => CategoryView(
                                key: subcategory.categoryKey,
                                labelAr: subcategory.categoryKey,
                                iconName: ''),
                          )
                          .labelAr,
                      style: AppText.caption,
                    ),
                    trailing: IconButton(
                      key: ValueKey(
                          'unarchive-subcategory-${subcategory.key}'),
                      icon: const Icon(AppIcons.unarchive),
                      tooltip: 'استعادة',
                      onPressed: () => _unarchiveSubcategory(subcategory.key),
                    ),
                  ),
                const Divider(height: AppSpacing.lg),
                ListTile(
                  key: const Key('settings-recurring-bills'),
                  leading: const Icon(AppIcons.bill),
                  title: const Text('الفواتير المتكررة', style: AppText.body),
                  subtitle: const Text('تذكير قبل الميعاد وتسجيل الدفع',
                      style: AppText.caption),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        RecurringBillsScreen(repository: widget.repository),
                  )),
                ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('البيانات'),
                ListTile(
                  key: const Key('settings-import'),
                  leading: const Icon(AppIcons.importData),
                  title: const Text('استيراد', style: AppText.body),
                  subtitle: const Text(
                      'البيانات المرفقة، ملف JSON أو ملاحظة سامسونج أو نص',
                      style: AppText.caption),
                  onTap: _openImport,
                ),
                const Divider(height: AppSpacing.lg),
                const _SectionHeader('المزايا الأونلاين'),
                OnlineSettingsSection(
                  repository: widget.repository,
                  keyStore: _geminiKeys,
                  gemini: _gemini,
                ),
                if (ThemeModeScope.maybeOf(context) case final themeMode?) ...[
                  const Divider(height: AppSpacing.lg),
                  const _SectionHeader('المظهر'),
                  _ThemeModeSelector(controller: themeMode),
                ],
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
  final Widget? trailing;

  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(title, style: AppText.title),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// System / light / dark. The choice applies the moment it is tapped and
/// is remembered in `app_settings` by [ThemeModeController].
class _ThemeModeSelector extends StatelessWidget {
  final ThemeModeController controller;

  const _ThemeModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SegmentedButton<ThemeMode>(
        key: const Key('settings-theme-mode'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(AppIcons.themeSystem, key: Key('settings-theme-system')),
            label: Text('تلقائي'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(AppIcons.themeLight, key: Key('settings-theme-light')),
            label: Text('فاتح'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(AppIcons.themeDark, key: Key('settings-theme-dark')),
            label: Text('داكن'),
          ),
        ],
        selected: {controller.value},
        onSelectionChanged: (selection) =>
            controller.select(selection.single),
      ),
    );
  }
}
