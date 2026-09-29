import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/design/tokens.dart';
import '../../../data/gemini_usage_log.dart';
import '../../../domain/gemini_usage.dart';
import '../../../domain/spending_repository.dart';

/// Gemini API usage (plan, Task 12): requests and tokens today and this
/// month, the share of each feature, the failures with the last error, an
/// estimated cost at the paid-tier prices, and the free tier's daily
/// request limit with a bar of today's use. The prices and the limit are
/// settings; «مسح العداد» starts the month again.
///
/// Read when the screen opens: Settings is not open while a capture is
/// being improved, so the numbers cannot go stale under the user.
class GeminiUsageCard extends StatefulWidget {
  final SpendingRepository repository;
  final DateTime Function() clock;

  const GeminiUsageCard({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
  });

  @override
  State<GeminiUsageCard> createState() => _GeminiUsageCardState();
}

class _GeminiUsageCardState extends State<GeminiUsageCard> {
  SpendingRepository get _repo => widget.repository;
  late final _log = GeminiUsageLog(_repo);

  final _inputPrice = TextEditingController(text: defaultGeminiInputPrice);
  final _outputPrice = TextEditingController(text: defaultGeminiOutputPrice);
  final _limit = TextEditingController(text: '$defaultGeminiDailyLimit');

  GeminiMonthUsage? _usage;

  static final _count = NumberFormat('#,##0', 'en_US');
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputPrice.dispose();
    _outputPrice.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final usage = await _log.month(widget.clock());
      final input = await _repo.setting(geminiInputPriceSettingKey);
      final output = await _repo.setting(geminiOutputPriceSettingKey);
      final limit = await _repo.setting(geminiDailyLimitSettingKey);
      if (!mounted) return;
      setState(() {
        _usage = usage;
        if (input != null && parseUsdPrice(input) != null) {
          _inputPrice.text = input;
        }
        if (output != null && parseUsdPrice(output) != null) {
          _outputPrice.text = output;
        }
        if (limit != null && _readLimit(limit) != null) _limit.text = limit;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _usage = GeminiMonthUsage.empty(''));
      }
    }
  }

  static int? _readLimit(String text) {
    final limit = int.tryParse(text.trim());
    return limit != null && limit > 0 ? limit : null;
  }

  /// Saves a price or the limit once the field is done with. Something
  /// that does not read is not saved, and the field goes back to what is.
  Future<void> _saveField(String key, TextEditingController field,
      bool Function(String) valid) async {
    final text = field.text.trim();
    if (!valid(text)) {
      final saved = await _repo.setting(key);
      if (!mounted) return;
      setState(() => field.text = saved ?? _defaultOf(key));
      return;
    }
    try {
      await _repo.setSetting(key, text);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  static String _defaultOf(String key) => switch (key) {
        geminiInputPriceSettingKey => defaultGeminiInputPrice,
        geminiOutputPriceSettingKey => defaultGeminiOutputPrice,
        _ => '$defaultGeminiDailyLimit',
      };

  Future<void> _reset() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح العداد'),
        content: const Text('عداد الشهر ده هيبدأ من الأول.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            key: const Key('gemini-usage-reset-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('امسح'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _log.reset(widget.clock());
    } catch (_) {}
    await _load();
  }

  String _line(GeminiUsageCounts counts) =>
      '${_count.format(counts.requests)} طلب · '
      '${_count.format(counts.totalTokens)} توكن';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final usage = _usage;
    if (usage == null) return const SizedBox.shrink();
    final now = widget.clock();
    final today = usage.day(now);
    final limit =
        _readLimit(_limit.text) ?? defaultGeminiDailyLimit;
    final cost = estimateCostMicroUsd(
      usage.total,
      inputPrice: parseUsdPrice(_inputPrice.text) ??
          parseUsdPrice(defaultGeminiInputPrice)!,
      outputPrice: parseUsdPrice(_outputPrice.text) ??
          parseUsdPrice(defaultGeminiOutputPrice)!,
    );
    final secondary = AppText.caption.copyWith(color: palette.textSecondary);

    Widget row(String label, String value, {Key? key, Color? color}) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: AppText.body)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  value,
                  key: key,
                  textAlign: TextAlign.end,
                  style: AppText.label
                      .copyWith(color: color ?? palette.textPrimary),
                ),
              ),
            ],
          ),
        );

    Widget field(String label, Key key, TextEditingController controller,
            String settingKey, bool Function(String) valid) =>
        Expanded(
          child: TextField(
            key: key,
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: label, isDense: true),
            onSubmitted: (_) => _saveField(settingKey, controller, valid),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _saveField(settingKey, controller, valid);
            },
          ),
        );

    return Container(
      key: const Key('gemini-usage-card'),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('استخدام Gemini', style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          row('النهارده', _line(today), key: const Key('gemini-usage-today')),
          row('الشهر ده', _line(usage.total),
              key: const Key('gemini-usage-month')),
          for (final feature in GeminiUsageFeature.values)
            if (usage.feature(feature).requests > 0)
              Padding(
                padding:
                    const EdgeInsetsDirectional.only(start: AppSpacing.md),
                child: row(feature.labelAr, _line(usage.feature(feature)),
                    key: Key('gemini-usage-feature-${feature.name}')),
              ),
          row('فشل', _count.format(usage.total.failures),
              key: const Key('gemini-usage-failures'),
              color: usage.total.failures > 0 ? palette.negative : null),
          if (usage.lastError != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: Text(
                'آخر خطأ: ${usage.lastError}'
                '${usage.lastErrorAt == null ? '' : ' (${_stamp.format(usage.lastErrorAt!)})'}',
                key: const Key('gemini-usage-last-error'),
                style: secondary,
              ),
            ),
          row('التكلفة التقديرية (الخطة المدفوعة)', formatUsdMicro(cost),
              key: const Key('gemini-usage-cost')),
          Text(
            'الخطة المجانية: مفيش فلوس طول ما انت جوه حدود جوجل اليومية.',
            style: secondary,
          ),
          const SizedBox(height: AppSpacing.ms),
          Text(
            '${_count.format(today.requests)} من ${_count.format(limit)} '
            'طلب النهارده',
            key: const Key('gemini-usage-limit'),
            style: AppText.label.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              key: const Key('gemini-usage-limit-bar'),
              value: (today.requests / limit).clamp(0.0, 1.0),
              minHeight: 8,
              color: today.requests >= limit
                  ? palette.negative
                  : palette.primary,
              backgroundColor: palette.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.ms),
          Row(
            children: [
              field('سعر المليون توكن داخل \$', const Key('gemini-price-input'),
                  _inputPrice, geminiInputPriceSettingKey,
                  (t) => parseUsdPrice(t) != null),
              const SizedBox(width: AppSpacing.sm),
              field('سعر المليون توكن خارج \$',
                  const Key('gemini-price-output'), _outputPrice,
                  geminiOutputPriceSettingKey, (t) => parseUsdPrice(t) != null),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              field('حد الطلبات المجاني في اليوم',
                  const Key('gemini-daily-limit'), _limit,
                  geminiDailyLimitSettingKey, (t) => _readLimit(t) != null),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('gemini-usage-reset'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _reset,
              child: const Text('مسح العداد'),
            ),
          ),
        ],
      ),
    );
  }
}
