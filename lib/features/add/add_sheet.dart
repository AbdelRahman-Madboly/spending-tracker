import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/amount_expression.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/photo_capture_service.dart';
import '../../domain/models.dart';
import '../../domain/spending_repository.dart';
import 'widgets/amount_keypad.dart';
import 'widgets/category_strip.dart';
import 'widgets/new_item_dialog.dart';
import 'widgets/subcategory_strip.dart';

/// What the add sheet starts as soon as it is up: how the dashboard's
/// capture bar reaches the photo and barcode capture this sheet already
/// has, until Phase C gives those flows screens of their own.
enum AddSheetAction { camera, gallery, barcode }

/// The payment methods the sheet offers, key to Arabic label. Keys are
/// English, as stored in `entries.paymentMethod`.
const paymentMethodLabels = {
  'Cash': 'كاش',
  'InstaPay': 'إنستاباي',
  'Card': 'كارت',
};

/// Money as the keypad types it: no thousands separator, two decimals only
/// when there are piastres. `4000` is `40`, `2250` is `22.50`.
String keypadText(int piastres) {
  final pounds = piastres ~/ 100;
  final fraction = piastres % 100;
  return fraction == 0
      ? '$pounds'
      : '$pounds.${fraction.toString().padLeft(2, '0')}';
}

/// The add sheet (spec §6.1), keypad first: the amount is typed (or
/// calculated) on the keypad, the eight recent chips above it fill amount,
/// category and item in one tap, and the category → subcategory → item
/// strips below it file the spend. The payment method starts on the last
/// one used. Saving needs an amount above zero and a category.
class AddSheet extends StatefulWidget {
  final SpendingRepository repository;

  /// Saves the entry. حفظ stays disabled until it completes, so a quick
  /// double tap cannot save the same spend twice; if it throws, the sheet
  /// stays open and says the save failed.
  final FutureOr<void> Function(DraftEntry) onSubmit;

  /// Defaults to the real image_picker/permission_handler-backed
  /// implementation; overridable so widget tests can inject a fake — the
  /// real one talks to platform channels that don't run under
  /// `flutter test`.
  final PhotoCaptureService? photoCaptureService;

  /// Defaults to the real mobile_scanner-backed implementation;
  /// overridable so widget tests can feed a fixed barcode value without a
  /// real camera.
  final BarcodeScanService? barcodeScanService;

  /// Started once the first frame is up; null starts nothing.
  final AddSheetAction? initialAction;

  const AddSheet({
    super.key,
    required this.repository,
    required this.onSubmit,
    this.photoCaptureService,
    this.barcodeScanService,
    this.initialAction,
  });

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  /// What the keypad holds, e.g. `2×35+10`.
  String _expression = '';

  /// True right after a chip, tile or scan filled [_expression]: the next
  /// digit starts a new amount, while an operator builds on the filled one
  /// (tap شويبس, then ×3 for three of them).
  bool _filled = false;

  /// The picked item, if any. Its category and subcategory file the entry.
  QuickPickItem? _item;
  EntrySource _source = EntrySource.manual;
  String _paymentMethod = 'Cash';

  /// True once the user taps a payment chip. The last used method loads
  /// asynchronously and must not overwrite a choice already made.
  bool _paymentTouched = false;

  /// True while [widget.onSubmit] runs; حفظ is disabled meanwhile.
  bool _saving = false;

  List<QuickPickItem> _recent = const [];
  List<QuickPickItem> _items = const [];
  List<CategoryView> _categories = const [];
  List<SubcategoryView> _subcategories = const [];

  /// Created lazily (not in [initState]) so nothing touches image_picker's
  /// platform channel until the user actually taps a capture button —
  /// widget tests that never tap camera/gallery never pay for it.
  PhotoCaptureService? _photoCaptureService;
  PhotoCaptureService get _photoCapture => _photoCaptureService ??=
      widget.photoCaptureService ?? ImagePickerPhotoCaptureService();

  /// Same lazy-creation reasoning as [_photoCapture]: nothing touches the
  /// camera until the barcode button is actually tapped.
  BarcodeScanService? _barcodeScanService;
  BarcodeScanService get _barcodeScan => _barcodeScanService ??=
      widget.barcodeScanService ?? MobileScannerBarcodeScanService();

  /// Every photo relative path attached at any point during this sheet's
  /// lifetime — including one later replaced by another capture. On
  /// dispose, anything in here that didn't end up in a saved entry gets
  /// deleted, so dismissing the sheet (or swapping photos) never leaves an
  /// orphaned file under documents/photos/ forever. See [_cleanupAbandonedPhotos].
  final Set<String> _sessionPhotoPaths = {};

  /// Set once [widget.onSubmit] has completed without throwing — tells
  /// [_cleanupAbandonedPhotos] that the sheet's current [_photoPath] (if
  /// any) was actually persisted and must be kept.
  bool _saved = false;

  /// Relative path of the currently attached photo, if any. Photo and
  /// amount/item can be set in either order; the draft picks it up at save.
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
    widget.repository.recentItems(8).then((items) {
      if (mounted) setState(() => _recent = items);
    });
    widget.repository.setting(lastPaymentMethodSettingKey).then((method) {
      if (mounted && method != null && !_paymentTouched) {
        setState(() => _paymentMethod = method);
      }
    });
    _loadItems();
    final action = widget.initialAction;
    if (action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (action) {
          case AddSheetAction.camera:
            _captureFromCamera();
          case AddSheetAction.gallery:
            _pickFromGallery();
          case AddSheetAction.barcode:
            _scanBarcode();
        }
      });
    }
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
      // Choosing another category over the picked item's says the item was
      // the wrong one; the chosen category wins.
      if (categoryKey != null && _item?.categoryKey != categoryKey) {
        _item = null;
      }
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
    setState(() {
      _selectedSubcategoryKey = subcategoryKey;
      if (subcategoryKey != null && _item?.subcategoryKey != subcategoryKey) {
        _item = null;
      }
    });
    _loadItems();
  }

  void _select(
    QuickPickItem item, {
    EntrySource source = EntrySource.quickPick,
  }) {
    final amount = item.suggestedAmountPiastres;
    setState(() {
      _item = item;
      _source = source;
      _expression = amount == null ? '' : keypadText(amount);
      _filled = amount != null;
    });
  }

  /// One keypad key. Keeps [_expression] something the calculator can read:
  /// no leading operator, one operator between operands (a second replaces
  /// the first), one decimal point and at most two decimals per operand.
  void _press(String key) {
    setState(() {
      var text = _expression;
      if (key == keypadBackspace) {
        _filled = false;
        if (text.isNotEmpty) text = text.substring(0, text.length - 1);
        _expression = text;
        return;
      }
      if (keypadOperators.contains(key)) {
        _filled = false;
        if (text.endsWith('.')) text = text.substring(0, text.length - 1);
        if (text.isEmpty) return;
        if (keypadOperators.contains(text[text.length - 1])) {
          text = text.substring(0, text.length - 1);
        }
        _expression = '$text$key';
        return;
      }
      if (_filled) {
        text = '';
        _filled = false;
      }
      if (text.length >= 32) return;
      final operand = text.split(RegExp('[${keypadOperators.join()}]')).last;
      if (key == '.') {
        if (operand.contains('.')) return;
        _expression = operand.isEmpty ? '${text}0.' : '$text.';
        return;
      }
      final dot = operand.indexOf('.');
      if (dot >= 0 && operand.length - dot > 2) return;
      _expression = '$text$key';
    });
  }

  int? get _amount => evaluateAmountExpression(_expression);

  String? get _categoryKey => _item?.categoryKey ?? _selectedCategoryKey;

  /// Null until there is an amount above zero and a category to file it in.
  DraftEntry? get _draft {
    final amount = _amount;
    final categoryKey = _categoryKey;
    if (amount == null || amount <= 0 || categoryKey == null) return null;
    final item = _item;
    return DraftEntry(
      amountPiastres: amount,
      itemId: item?.id,
      description: item?.nameAr,
      categoryKey: categoryKey,
      // The item's own catalogue subcategory, not whatever filter the grid
      // happens to be scoped to.
      subcategoryKey: item != null
          ? item.subcategoryKey
          : _selectedSubcategoryKey,
      paymentMethod: _paymentMethod,
      source: item != null ? _source : EntrySource.manual,
      photoPath: _photoPath,
    );
  }

  Future<void> _captureFromCamera() =>
      _capture(_photoCapture.captureFromCamera);

  Future<void> _pickFromGallery() => _capture(_photoCapture.pickFromGallery);

  Future<void> _capture(Future<PhotoCaptureResult> Function() capture) async {
    final result = await capture();
    if (!mounted) return;
    switch (result.outcome) {
      case PhotoCaptureOutcome.cancelled:
        return;
      case PhotoCaptureOutcome.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر الوصول إلى الكاميرا. يرجى السماح بإذن الكاميرا من إعدادات التطبيق.',
            ),
          ),
        );
        return;
      case PhotoCaptureOutcome.attached:
        final relativePath = result.relativePath!;
        final file = await _photoCapture.resolve(relativePath);
        if (!mounted) return;
        _sessionPhotoPaths.add(relativePath);
        setState(() {
          _photoPath = relativePath;
          _photoFile = file;
        });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoFile = null;
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
    final fallbackCategoryKey = _categories.isNotEmpty
        ? _categories.first.key
        : 'Food';
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
    final draft = _draft;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAmountHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_photoFile != null) _buildPhoto(context),
                    _buildRecentChips(context),
                    const SizedBox(height: AppSpacing.sm),
                    AmountKeypad(onKey: _press),
                    const SizedBox(height: AppSpacing.sm),
                    CategoryStrip(
                      categories: _categories,
                      selectedKey: _selectedCategoryKey,
                      onSelected: _selectCategory,
                    ),
                    // Only exists once a real category is selected: الكل
                    // never has to make room for it.
                    if (_selectedCategoryKey != null)
                      SubcategoryStrip(
                        subcategories: _subcategories,
                        selectedKey: _selectedSubcategoryKey,
                        onSelected: _selectSubcategory,
                        colorKey: _colorKeyOf(_selectedCategoryKey),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildItemGrid(context),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentMethods(context),
                  ],
                ),
              ),
            ),
            // Pinned under the scrolling part so حفظ is always in thumb
            // reach, however much of the sheet is scrolled (spec §8).
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: FilledButton(
                key: const Key('save-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: draft == null || _saving
                    ? null
                    : () => _submit(draft),
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(DraftEntry draft) async {
    setState(() => _saving = true);
    try {
      await widget.onSubmit(draft);
      // Only now is the attached photo part of a saved entry; before, a
      // failed save would have kept an orphaned file.
      _saved = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('save-failed'),
            content: Text('ما اتحفظش المصروف. جرّب تاني.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _colorKeyOf(String? categoryKey) {
    for (final c in _categories) {
      if (c.key == categoryKey) return c.colorKey;
    }
    return null;
  }

  /// What the entry will be filed as, above the amount: the item's name,
  /// else the chosen category's label, else a prompt.
  String _subject() {
    final item = _item;
    if (item != null) return item.nameAr;
    for (final c in _categories) {
      if (c.key == _selectedCategoryKey) return c.labelAr;
    }
    return 'المبلغ';
  }

  Widget _buildAmountHeader(BuildContext context) {
    final palette = context.palette;
    final amount = _amount;
    final hasOperator = keypadOperators.any(_expression.contains);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _subject(),
                  key: const Key('amount-subject'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: palette.textSecondary),
                ),
                // A long calculation shrinks instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _expression.isEmpty ? '0' : _expression,
                    key: const Key('amount-expression'),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: AppText.display.copyWith(
                      color: _expression.isEmpty
                          ? palette.textSecondary
                          : palette.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: hasOperator && amount != null
                      ? Text(
                          '= ${formatPiastres(amount)}',
                          key: const Key('amount-total'),
                          textDirection: TextDirection.ltr,
                          style: AppText.label.copyWith(color: palette.primary),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Row(
            key: const Key('capture-icons'),
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('camera-button'),
                tooltip: 'صورة',
                onPressed: _captureFromCamera,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(AppIcons.camera, color: palette.textSecondary),
              ),
              IconButton(
                key: const Key('gallery-button'),
                tooltip: 'من المعرض',
                onPressed: _pickFromGallery,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(AppIcons.gallery, color: palette.textSecondary),
              ),
              IconButton(
                key: const Key('barcode-button'),
                tooltip: 'باركود',
                onPressed: _scanBarcode,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(AppIcons.barcode, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Image.file(
              _photoFile!,
              key: const Key('photo-thumbnail'),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
                color: palette.surfaceAlt,
                child: Icon(AppIcons.brokenImage, color: palette.textSecondary),
              ),
            ),
          ),
          IconButton(
            key: const Key('remove-photo-button'),
            tooltip: 'شيل الصورة',
            onPressed: _removePhoto,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    );
  }

  /// The eight recent/frequent items (spec §6.1), one row that scrolls
  /// sideways, each chip showing the price a tap will fill in.
  Widget _buildRecentChips(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      key: const Key('recent-chips'),
      height: 48,
      // A Row, not a lazy ListView, so all eight chips are always built.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _recent)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                child: Material(
                  color: _item?.id == item.id
                      ? palette.primaryContainer
                      : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: InkWell(
                    key: Key('recent-${item.id}'),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    onTap: () => _select(item),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.ms,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.nameAr,
                            style: AppText.label.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          if (item.suggestedAmountPiastres != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              formatPiastres(item.suggestedAmountPiastres!),
                              textDirection: TextDirection.ltr,
                              style: AppText.caption.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(BuildContext context) {
    final palette = context.palette;
    // Cap tile WIDTH rather than fixing a column count. Tile height derives
    // from tile width, so a fixed count makes tiles balloon on a wide surface
    // and collapse below the 48dp touch target if the ratio is tuned to
    // compensate. Capping width holds tiles near 69dp tall on a phone (3
    // columns) and simply reflows to more columns on anything wider.
    return GridView.extent(
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
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              // surfaceAlt, not surface: the sheet itself is surface, and a
              // tile the same colour as its ground only shows once selected.
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: _item?.id == item.id
                      ? palette.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Always one line: a long user-supplied name truncates
                    // rather than wrapping out of the tile.
                    Text(
                      item.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body,
                    ),
                    if (item.suggestedAmountPiastres != null)
                      Text(
                        formatPiastres(item.suggestedAmountPiastres!),
                        style: AppText.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        InkWell(
          key: const Key('new-item-tile'),
          onTap: _openNewItemDialog,
          borderRadius: BorderRadius.circular(AppRadii.sm),
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
                Text(
                  'جديد',
                  style: AppText.caption.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// كاش / إنستاباي / كارت, starting on the last one used. A stored method
  /// the list doesn't know (an imported `Etisalat`) is offered too, so the
  /// preselection is never silently swapped for Cash.
  Widget _buildPaymentMethods(BuildContext context) {
    final methods = {
      ...paymentMethodLabels,
      if (!paymentMethodLabels.containsKey(_paymentMethod))
        _paymentMethod: _paymentMethod,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final MapEntry(key: method, value: label) in methods.entries)
            SelectableChip(
              key: Key('payment-$method'),
              label: label,
              icon: AppIcons.payment,
              selected: _paymentMethod == method,
              onTap: () => setState(() {
                _paymentTouched = true;
                _paymentMethod = method;
              }),
            ),
        ],
      ),
    );
  }
}
