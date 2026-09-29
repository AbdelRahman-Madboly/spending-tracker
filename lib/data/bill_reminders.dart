import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/money.dart';
import '../domain/bills.dart';
import '../domain/dashboard.dart' show arabicMonthName;
import '../domain/models.dart';
import '../domain/spending_repository.dart';
import '../domain/transactions.dart';

/// Shows local notifications at a given moment. No network is involved.
abstract class ReminderNotifier {
  Future<void> cancelAll();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Asks for POST_NOTIFICATIONS (Android 13+); true when granted.
  Future<bool> requestPermission();
}

/// Keeps one reminder per live recurring bill scheduled. Called on app
/// start and after every bill change; the plugin's own boot receiver puts
/// the scheduled ones back after a reboot.
class BillReminders {
  BillReminders(this._notifier, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ReminderNotifier _notifier;
  final DateTime Function() _clock;

  /// The app's own, on the real notifications plugin. Tests replace it.
  static BillReminders shared = BillReminders(LocalReminderNotifier());

  Future<bool> requestPermission() async {
    try {
      return await _notifier.requestPermission();
    } catch (error) {
      debugPrint('bill reminders: permission request failed: $error');
      return false;
    }
  }

  /// Replaces every scheduled reminder with one per bill in [bills] that
  /// is not archived and whose reminder moment is still ahead. A failure
  /// (no plugin, a refused permission) is logged, never thrown: a missing
  /// reminder must not break saving a bill.
  Future<void> reschedule(List<RecurringBillView> bills) async {
    try {
      await _notifier.cancelAll();
      final now = _clock();
      var id = 0;
      for (final bill in bills) {
        if (bill.archived) continue;
        final at = reminderTime(bill, now);
        if (at == null) continue;
        final due = bill.nextDue;
        await _notifier.schedule(
          id: id++,
          at: at,
          title: 'فاتورة قربت: ${bill.nameAr}',
          body: '${formatPiastres(bill.amountPiastres)} جنيه، مستحقة '
              '${arabicWeekdayName(due.weekday)} ${due.day} '
              '${arabicMonthName(due.month)}',
        );
      }
    } catch (error) {
      debugPrint('bill reminders: scheduling failed: $error');
    }
  }

  Future<void> rescheduleFrom(SpendingRepository repository) async {
    final List<RecurringBillView> bills;
    try {
      bills = await repository.recurringBills();
    } catch (error) {
      debugPrint('bill reminders: reading bills failed: $error');
      return;
    }
    await reschedule(bills);
  }
}

/// [ReminderNotifier] on flutter_local_notifications, scheduled inexactly
/// (no exact-alarm permission): a reminder may show a little late.
class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bill_reminders',
      'تذكير الفواتير',
      channelDescription: 'تذكير قبل ميعاد الفواتير المتكررة',
    ),
  );

  Future<void> _init() => _ready ??= _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _init();
    await _plugin.zonedSchedule(
      id: id,
      // The moment itself; UTC needs no time zone database and names a
      // zone Android knows, so the device's own zone shows it on time.
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }
}
