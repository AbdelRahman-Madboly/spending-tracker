import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../core/quantity.dart';
import '../../../domain/models.dart';

/// What the quantity step settled on: how much was bought and the price of
/// one unit. [totalPiastres] is what is recorded.
class UnitPurchase {
  const UnitPurchase({
    required this.quantityMilli,
    required this.unitPricePiastres,
  });

  final int quantityMilli;
  final int unitPricePiastres;

  int get totalPiastres => totalForQuantity(unitPricePiastres, quantityMilli);
}

/// The quick amounts offered for [unit], in milli-units: halves up to three
/// for a litre or a kilo, the usual weights for grams, whole counts for
/// anything else.
List<int> quickQuantities(String unit) => switch (unit) {
      'liter' || 'kg' => const [500, 1000, 1500, 2000, 3000],
      'g' => const [250000, 500000, 1000000],
      _ => const [1000, 2000, 3000],
    };

/// A quick amount's chip label: نص for half, else the number.
String quickQuantityLabel(int milli) =>
    milli == 500 ? 'نص' : formatQuantityMilli(milli);

/// Asks how much of [item] (a product sold loose by a unit) was bought and
/// at what price per unit. Null when the user closed it without saving.
Future<UnitPurchase?> showUnitQuantityStep(
  BuildContext context,
  QuickPickItem item,
) =>
    showModalBottomSheet<UnitPurchase>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => UnitQuantityStep(item: item),
    );

/// The compact step between tapping a loose product and saving it: the
/// quantity (typed, or one of the quick chips), the price per unit
/// (prefilled with the last one paid, and required), and the live total.
class UnitQuantityStep extends StatefulWidget {
  const UnitQuantityStep({super.key, required this.item});

  final QuickPickItem item;

  @override
  State<UnitQuantityStep> createState() => _UnitQuantityStepState();
}

class _UnitQuantityStepState extends State<UnitQuantityStep> {
  String get _unit => widget.item.unit!;

  late final _quantity = TextEditingController(
    text: switch (widget.item.defaultQuantityMilli) {
      final q? => formatQuantityMilli(q),
      // Grams have no sensible "one"; the chips say what is usual.
      null => _unit == 'g' ? '' : '1',
    },
  );
  late final _price = TextEditingController(
    text: switch (widget.item.suggestedAmountPiastres) {
      final p? => formatPiastres(p).replaceAll(',', ''),
      null => '',
    },
  );
  String? _quantityError;
  String? _priceError;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  int? get _quantityMilli => parseQuantityMilli(_quantity.text);

  int? get _unitPrice {
    final text = _price.text.trim();
    final price = text.isEmpty ? null : parsePiastres(text);
    return price == null || price <= 0 ? null : price;
  }

  void _pickQuick(int milli) {
    HapticFeedback.selectionClick();
    setState(() {
      _quantity.text = formatQuantityMilli(milli);
      _quantityError = null;
    });
  }

  void _save() {
    final quantity = _quantityMilli;
    final price = _unitPrice;
    setState(() {
      _quantityError = quantity == null ? 'اكتب الكمية' : null;
      _priceError = price == null ? 'اكتب ${pricePerUnitLabel(_unit)}' : null;
    });
    if (quantity == null || price == null) return;
    Navigator.of(context).pop(
      UnitPurchase(quantityMilli: quantity, unitPricePiastres: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unitLabel = entryUnitLabels[_unit] ?? _unit;
    final quantity = _quantityMilli;
    final price = _unitPrice;
    final total = quantity == null || price == null
        ? null
        : totalForQuantity(price, quantity);
    return Padding(
      key: const Key('unit-step'),
      // Keeps the fields and حفظ above the keyboard.
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.gutter,
        end: AppSpacing.gutter,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item.nameAr, style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('unit-quantity'),
              controller: _quantity,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppText.body,
              decoration: InputDecoration(
                labelText: 'الكمية',
                suffixText: unitLabel,
                errorText: _quantityError,
              ),
              onChanged: (_) => setState(() => _quantityError = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final milli in quickQuantities(_unit))
                  ChoiceChip(
                    key: ValueKey('unit-quick-$milli'),
                    label: Text(quickQuantityLabel(milli)),
                    selected: quantity == milli,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => _pickQuick(milli),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('unit-price'),
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppText.body,
              decoration: InputDecoration(
                labelText: pricePerUnitLabel(_unit),
                suffixText: 'ج.م',
                errorText: _priceError,
              ),
              onChanged: (_) => setState(() => _priceError = null),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الإجمالي',
                    style:
                        AppText.label.copyWith(color: palette.textSecondary),
                  ),
                ),
                // A large total shrinks rather than overflowing.
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      total == null
                          ? '—'
                          : formatPiastres(total, withCurrency: true),
                      key: const Key('unit-total'),
                      style: AppText.headline.copyWith(
                        color: total == null
                            ? palette.textSecondary
                            : palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('unit-save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _save,
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
