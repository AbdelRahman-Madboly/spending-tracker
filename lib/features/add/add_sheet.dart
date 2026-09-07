import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'widgets/category_strip.dart';
import 'widgets/new_item_dialog.dart';
import 'widgets/subcategory_strip.dart';

class AddSheet extends StatefulWidget {
  final SpendingRepository repository;
  final ValueChanged<DraftEntry> onSubmit;

  const AddSheet({super.key, required this.repository, required this.onSubmit});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  DraftEntry? _draft;
  List<QuickPickItem> _items = const [];
  List<CategoryView> _categories = const [];
  List<SubcategoryView> _subcategories = const [];

  /// null means "الكل" (all categories) — the default, so the most-used
  /// items across every category (and the two-tap path to them) is always
  /// what the user sees first.
  String? _selectedCategoryKey;

  /// null means "الكل" within the selected category — the whole category,
  /// unfiltered by subcategory. Only meaningful once a real category is
  /// selected; the second chip row doesn't exist otherwise.
  String? _selectedSubcategoryKey;

  @override
  void initState() {
    super.initState();
    widget.repository.categories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _loadItems();
  }

  void _loadItems() {
    final categoryKey = _selectedCategoryKey;
    final subcategoryKey = _selectedSubcategoryKey;
    final Future<List<QuickPickItem>> future;
    if (subcategoryKey != null) {
      future = widget.repository.itemsInSubcategory(subcategoryKey, 12);
    } else if (categoryKey != null) {
      future = widget.repository.itemsInCategory(categoryKey, 12);
    } else {
      future = widget.repository.topItems(12);
    }
    future.then((items) {
      if (mounted) setState(() => _items = items);
    });
  }

  void _selectCategory(String? categoryKey) {
    setState(() {
      _selectedCategoryKey = categoryKey;
      _selectedSubcategoryKey = null;
      if (categoryKey == null) _subcategories = const [];
    });
    if (categoryKey != null) {
      widget.repository.subcategories(categoryKey).then((subs) {
        if (mounted) setState(() => _subcategories = subs);
      });
    }
    _loadItems();
  }

  void _selectSubcategory(String? subcategoryKey) {
    setState(() => _selectedSubcategoryKey = subcategoryKey);
    _loadItems();
  }

  void _select(QuickPickItem item) {
    setState(() {
      _draft = DraftEntry(
        amountPiastres: item.defaultAmountPiastres,
        itemId: item.id,
        description: item.nameAr,
        categoryKey: item.categoryKey,
        // The item's own catalogue subcategory, not whatever filter the
        // grid currently happens to be scoped to — so الكل still records
        // the right subcategory when the item's catalogue row has one.
        subcategoryKey: item.subcategoryKey,
        paymentMethod: 'Cash',
        source: EntrySource.quickPick,
      );
    });
  }

  Future<void> _openNewItemDialog() async {
    final fallbackCategoryKey =
        _categories.isNotEmpty ? _categories.first.key : 'Food';
    final categoryKey = _selectedCategoryKey ?? fallbackCategoryKey;
    // The second chip row already holds the selected category's
    // subcategories; only fetch them when there's nothing loaded yet
    // (i.e. الكل is selected, so جديد falls back to the first category).
    final subcategoriesForDialog = _selectedCategoryKey != null
        ? _subcategories
        : await widget.repository.subcategories(categoryKey);
    if (!mounted) return;

    final result = await showNewItemDialog(
      context: context,
      categories: _categories,
      initialCategoryKey: categoryKey,
      subcategories: subcategoriesForDialog,
      initialSubcategoryKey: _selectedSubcategoryKey,
    );
    if (result == null || !mounted) return;

    final created = await widget.repository.createItem(
      nameAr: result.nameAr,
      categoryKey: result.categoryKey,
      subcategoryKey: result.subcategoryKey,
      defaultAmountPiastres: result.amountPiastres,
    );
    if (!mounted) return;

    setState(() => _items = [created, ..._items]);
    _select(created);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (draft != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '${draft.description}  ${formatPiastres(draft.amountPiastres ?? 0, withCurrency: true)}',
                      style: AppText.title,
                    ),
                  ),
                CategoryStrip(
                  categories: _categories,
                  selectedKey: _selectedCategoryKey,
                  onSelected: _selectCategory,
                ),
                // Only exists once a real category is selected — الكل never
                // has to make room for it, so the two-tap quick-pick path
                // never grows an extra row of chips it didn't ask for.
                if (_selectedCategoryKey != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SubcategoryStrip(
                    subcategories: _subcategories,
                    selectedKey: _selectedSubcategoryKey,
                    onSelected: _selectSubcategory,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // Cap tile WIDTH rather than fixing a column count. Tile height derives
                // from tile width, so a fixed count makes tiles balloon on a wide surface
                // and collapse below the 48dp touch target if the ratio is tuned to
                // compensate. Capping width holds tiles near 69dp tall on a phone (3
                // columns) and simply reflows to more columns on anything wider.
                GridView.extent(
                  maxCrossAxisExtent: 130,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.5,
                  children: [
                    for (final item in _items)
                      InkWell(
                        onTap: () => _select(item),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _draft?.itemId == item.id
                                  ? AppColors.accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Always one line. Item names become user-supplied, and a
                                // long one must truncate rather than wrap and overflow
                                // the tile.
                                Text(
                                  item.nameAr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body,
                                ),
                                if (item.defaultAmountPiastres != null)
                                  Text(
                                      formatPiastres(
                                          item.defaultAmountPiastres!),
                                      style: AppText.caption),
                              ],
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      key: const Key('new-item-tile'),
                      onTap: _openNewItemDialog,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: AppColors.accent),
                            Text('جديد', style: AppText.caption),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  key: Key('capture-icons'),
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        color: AppColors.textSecondary),
                    Icon(Icons.qr_code_scanner,
                        color: AppColors.textSecondary),
                    Icon(Icons.mic_none, color: AppColors.textSecondary),
                    Icon(Icons.image_outlined,
                        color: AppColors.textSecondary),
                    Icon(Icons.keyboard_alt_outlined,
                        color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save-button'),
                    onPressed: draft != null && draft.isComplete
                        ? () => widget.onSubmit(draft)
                        : null,
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
