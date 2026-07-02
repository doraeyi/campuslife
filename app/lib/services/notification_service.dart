import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/card_model.dart';
import '../models/job.dart';

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

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  // 信用卡還款日：card.paymentDueDate 儲存每月幾號（e.g. "25"）
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
      if (diff < 0 || diff > 3) continue;

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

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(iOS: _iosDetails),
    );
  }
}
