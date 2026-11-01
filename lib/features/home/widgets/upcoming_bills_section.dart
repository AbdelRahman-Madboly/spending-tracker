import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';
import 'section_card.dart';

/// Recurring bills due soon (already filtered and capped by
/// `upcomingBills`). The caller hides the section when there are none.
class UpcomingBillsSection extends StatelessWidget {
  final List<RecurringBillView> bills;
  final DateTime today;

  const UpcomingBillsSection({
    super.key,
    required this.bills,
    required this.today,
  });

  String _dueLabel(DateTime due) {
    final day = DateTime.utc(today.year, today.month, today.day);
    final days =
        DateTime.utc(due.year, due.month, due.day).difference(day).inDays;
    if (days < 0) return 'متأخرة';
    if (days == 0) return 'النهارده';
    if (days == 1) return 'بكرة';
    return 'بعد $days أيام';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SectionCard(
      key: const Key('upcoming-bills-section'),
      title: 'فواتير جاية',
      child: Column(
        children: [
          for (final bill in bills)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Icon(AppIcons.bill, color: palette.primary),
                  const SizedBox(width: AppSpacing.ms),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(bill.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body),
                        Text(
                          _dueLabel(bill.nextDue),
                          style: AppText.caption.copyWith(
                            color: bill.nextDue.isBefore(DateTime(
                                    today.year, today.month, today.day))
                                ? palette.negative
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPiastres(bill.amountPiastres),
                    textDirection: TextDirection.ltr,
                    style: AppText.bodyStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
