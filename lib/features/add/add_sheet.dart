import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/photo_capture_service.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'widgets/category_strip.dart';
import 'widgets/new_item_dialog.dart';
import 'widgets/subcategory_strip.dart';

class AddSheet extends StatefulWidget {
  final SpendingRepository repository;
  final ValueChanged<DraftEntry> onSubmit;

  /// Defaults to the real image_picker/permission_handler-backed
  /// implementation; overridable so widget tests can inject a fake — the
  /// real one talks to platform channels that don't run under
  /// `flutter test`.
  final PhotoCaptureService? photoCaptureService;

  /// Defaults to the real mobile_scanner-backed implementation;
  /// overridable so widget tests can feed a fixed barcode value without a
  /// real camera.
  final BarcodeScanService? barcodeScanService;

  const AddSheet({
    super.key,
    required this.repository,
    required this.onSubmit,
    this.photoCaptureService,
    this.barcodeScanService,
  });

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  DraftEntry? _draft;
  List<QuickPickItem> _items = const [];
  List<CategoryView> _categories = const [];
  List<SubcategoryView> _subcategories = const [];

  /// Created lazily (not in [initState]) so nothing touches image_picker's
  /// platform channel until the user actually taps a capture button —
  /// widget tests that never tap camera/gallery never pay for it.
  PhotoCaptureService? _photoCaptureService;
  PhotoCaptureService get _photoCapture =>
      _photoCaptureService ??= widget.photoCaptureService ?? ImagePickerPhotoCaptureService();

  /// Same lazy-creation reasoning as [_photoCapture]: nothing touches the
  /// camera until the barcode button is actually tapped.
  BarcodeScanService? _barcodeScanService;
  BarcodeScanService get _barcodeScan =>
      _barcodeScanService ??= widget.barcodeScanService ?? MobileScannerBarcodeScanService();

  /// Every photo relative path attached at any point during this sheet's
  /// lifetime — including one later replaced by another capture. On
  /// dispose, anything in here that didn't end up in a saved entry gets
  /// deleted, so dismissing the sheet (or swapping photos) never leaves an
  /// orphaned file under documents/photos/ forever. See [_cleanupAbandonedPhotos].
  final Set<String> _sessionPhotoPaths = {};

  /// Set right before [widget.onSubmit] is called — tells
  /// [_cleanupAbandonedPhotos] that the sheet's current [_photoPath] (if
  /// any) was actually persisted and must be kept.
  bool _saved = false;

  /// Relative path of the currently attached photo, if any — kept apart
  /// from [_draft] so a photo attached before an item is picked (_draft
  /// still null) survives to be folded into the draft once one exists.
  String? _photoPath;
  File? _photoFile;

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

  @override
  void dispose() {
    _cleanupAbandonedPhotos();
    super.dispose();
  }

  /// Deletes every photo attached during this sheet's lifetime that did
  /// NOT end up in a saved entry — a photo replaced by a later capture, or
  /// (the common case) every attached photo when the sheet is dismissed
  /// without saving at all. Never touches [_photoCapture] when nothing was
  /// ever attached, so tests that never open the camera/gallery never pay
  /// for constructing the real platform-channel-backed service.
  void _cleanupAbandonedPhotos() {
    if (_sessionPhotoPaths.isEmpty) return;
    final keep = _saved ? _photoPath : null;
    for (final path in _sessionPhotoPaths) {
      if (path == keep) continue;
      // Fire-and-forget: dispose() can't be async and nothing needs to
      // wait for the deletion to finish.
      _photoCapture.delete(path);
    }
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

  void _select(QuickPickItem item, {EntrySource source = EntrySource.quickPick}) {
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
        source: source,
        // Carries over a photo attached before an item was picked — photo
        // and item selection can happen in either order.
      ).withPhotoPath(_photoPath);
    });
  }

  Future<void> _captureFromCamera() => _capture(_photoCapture.captureFromCamera);

  Future<void> _pickFromGallery() => _capture(_photoCapture.pickFromGallery);

  Future<void> _capture(
      Future<PhotoCaptureResult> Function() capture) async {
    final result = await capture();
    if (!mounted) return;
    switch (result.outcome) {
      case PhotoCaptureOutcome.cancelled:
        return;
      case PhotoCaptureOutcome.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تعذّر الوصول إلى الكاميرا. يرجى السماح بإذن الكاميرا من إعدادات التطبيق.'),
        ));
        return;
      case PhotoCaptureOutcome.attached:
        final relativePath = result.relativePath!;
        final file = await _photoCapture.resolve(relativePath);
        if (!mounted) return;
        _sessionPhotoPaths.add(relativePath);
        setState(() {
          _photoPath = relativePath;
          _photoFile = file;
          if (_draft != null) _draft = _draft!.withPhotoPath(relativePath);
        });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoFile = null;
      if (_draft != null) _draft = _draft!.withPhotoPath(null);
    });
  }

  /// Opens the barcode/QR scanner. A known barcode selects its item as the
  /// draft instantly (the fast, offline-learned path); an unknown one
  /// opens the new-item dialog with the barcode attached, so naming and
  /// pricing it teaches the app that code for every future scan.
  Future<void> _scanBarcode() async {
    final barcode = await _barcodeScan.scan(context);
    if (!mounted || barcode == null) return;

    final existing = await widget.repository.itemByBarcode(barcode);
    if (!mounted) return;
    if (existing != null) {
      _select(existing, source: EntrySource.barcode);
      return;
    }
    await _openNewItemDialog(barcode: barcode, source: EntrySource.barcode);
  }

  Future<void> _openNewItemDialog({
    String? barcode,
    EntrySource source = EntrySource.quickPick,
  }) async {
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
      initialBarcode: barcode,
    );
    if (result == null || !mounted) return;

    final created = await widget.repository.createItem(
      nameAr: result.nameAr,
      categoryKey: result.categoryKey,
      subcategoryKey: result.subcategoryKey,
      defaultAmountPiastres: result.amountPiastres,
      barcode: result.barcode,
    );
    if (!mounted) return;

    setState(() => _items = [created, ..._items]);
    _select(created, source: source);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                          // surfaceAlt, not surface: the sheet itself is
                          // surface, and a tile the same colour as its
                          // ground only shows once it is selected.
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(
                              color: _draft?.itemId == item.id
                                  ? palette.primary
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
                                      style: AppText.caption.copyWith(
                                          color: palette.textSecondary)),
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
                          color: palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(AppIcons.add, color: palette.primary),
                            Text('جديد',
                                style: AppText.caption.copyWith(
                                    color: palette.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  key: const Key('capture-icons'),
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      key: const Key('camera-button'),
                      onPressed: _captureFromCamera,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(AppIcons.camera,
                          color: palette.textSecondary),
                    ),
                    IconButton(
                      key: const Key('barcode-button'),
                      onPressed: _scanBarcode,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(AppIcons.barcode,
                          color: palette.textSecondary),
                    ),
                    // Voice and manual-keyboard entry are separate tasks —
                    // these two stay inert placeholders here.
                    Icon(AppIcons.mic, color: palette.textSecondary),
                    IconButton(
                      key: const Key('gallery-button'),
                      onPressed: _pickFromGallery,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(AppIcons.gallery,
                          color: palette.textSecondary),
                    ),
                    Icon(AppIcons.keyboard, color: palette.textSecondary),
                  ],
                ),
                if (_photoFile != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _photoFile!,
                          key: const Key('photo-thumbnail'),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 64,
                            height: 64,
                            color: palette.surfaceAlt,
                            child: Icon(AppIcons.brokenImage,
                                color: palette.textSecondary),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('remove-photo-button'),
                        onPressed: _removePhoto,
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(AppIcons.close),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save-button'),
                    onPressed: draft != null && draft.isComplete
                        ? () {
                            _saved = true;
                            widget.onSubmit(draft);
                          }
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
