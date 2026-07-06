import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/card_model.dart';
import '../models/job.dart';
import '../models/shift.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const _shiftReminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'shift_reminder',
      '上班提醒',
      channelDescription: '班次開始前一小時的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: _iosDetails,
  );

  static const _generalDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'general',
      '一般通知',
      channelDescription: '信用卡還款、悠遊卡餘額、發薪日、自動記帳等即時提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: _iosDetails,
  );

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  // 班次開始前一小時提醒（例如 15:00 上班 → 14:00 通知）
  Future<void> scheduleShiftReminders(List<Shift> shifts) async {
    final now = tz.TZDateTime.now(tz.local);
    for (final shift in shifts) {
      final start = _shiftStart(shift);
      final remindAt = start.subtract(const Duration(hours: 1));
      if (remindAt.isBefore(now)) continue;

      final jobName = shift.job?.name;
      await _plugin.zonedSchedule(
        _shiftNotificationId(shift.id),
        '⏰ 上班提醒',
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
            '${jobName != null ? ' $jobName' : ''} 要上班了',
        remindAt,
        _shiftReminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelShiftReminder(int shiftId) =>
      _plugin.cancel(_shiftNotificationId(shiftId));

  int _shiftNotificationId(int shiftId) => 1000000 + shiftId;

  tz.TZDateTime _shiftStart(Shift shift) {
    final parts = shift.startTime.split(':');
    return tz.TZDateTime(
      tz.local,
      shift.date.year,
      shift.date.month,
      shift.date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // 信用卡還款日：card.paymentDueDate 儲存每月幾號（e.g. "25"）
  // 若使用者有設定 card.reminderDay（幾號提醒），則只在提醒日當天通知；
  // 否則沿用預設邏輯：還款日前 3 天內每天提醒。
  Future<void> checkCreditCardDueDates(List<AppCard> cards) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final card in cards) {
      if (card.type != 'credit' || card.paymentDueDate == null) continue;
      final day = int.tryParse(card.paymentDueDate!);
      if (day == null) continue;

      DateTime due = DateTime(now.year, now.month, day);
      if (due.isBefore(today)) {
        due = DateTime(now.year, now.month + 1, day);
      }
      final diff = due.difference(today).inDays;

      if (card.reminderDay != null) {
        if (card.reminderDay != now.day) continue;
      } else if (diff < 0 || diff > 3) {
        continue;
      }

      final label = diff == 0 ? '今天！' : diff == 1 ? '明天' : '${diff}天後';
      await _show(
        id: 100 + card.id,
        title: '💳 信用卡還款提醒',
        body: '${card.name} 還款日 ${due.month}/${due.day}（$label），記得繳款！',
      );
    }
  }

  // 悠遊卡餘額低於 100 元時提醒
  Future<void> checkEasyCardBalance(AppCard card) async {
    if (card.type != 'easycard' || card.balance == null) return;
    if (card.balance! < 100) {
      await _show(
        id: 200 + card.id,
        title: '🎫 悠遊卡餘額不足',
        body: '${card.name} 只剩 \$${card.balance!.toStringAsFixed(0)} 元，快去加值！',
      );
    }
  }

  // 今天是某工作的發薪日
  Future<void> checkSalaryReminder(List<Job> jobs) async {
    final today = DateTime.now().day;
    for (final job in jobs) {
      if (job.payday != null && job.payday == today) {
        await _show(
          id: 300 + job.id,
          title: '💰 今天是發薪日！',
          body: '${job.name} 今天發薪，記得確認入帳並記帳。',
        );
      }
    }
  }

  // 銀行通知截圖自動辨識、自動記帳成功時跳的通知
  Future<void> showBankNotifyResult(String merchant, double amount) async {
    await _show(
      id: 500000 + DateTime.now().millisecondsSinceEpoch % 100000,
      title: '✅ 已自動記帳',
      body: '$merchant -\$${amount.toStringAsFixed(0)}',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(id, title, body, _generalDetails);
  }
}
