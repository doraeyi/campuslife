import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import 'bank_notify_service.dart';
import 'parsers/parser_registry.dart';

/// Android-only advanced option (see B5 in the plan): listens for LINE
/// notifications via a native NotificationListenerService and auto-creates
/// transactions, on top of the screenshot+OCR baseline that works everywhere.
/// Only covers the case where the app process is alive — there's no
/// headless-engine fallback for a fully-killed process yet.
class AndroidBankNotificationListener {
  static const _methodChannel =
      MethodChannel('com.campuslife.campuslife/bank_notify');
  static const _eventChannel =
      EventChannel('com.campuslife.campuslife/bank_notifications');
  static const prefsKey = 'bank_notify_listener_enabled';

  static final AndroidBankNotificationListener _instance =
      AndroidBankNotificationListener._();
  factory AndroidBankNotificationListener() => _instance;
  AndroidBankNotificationListener._();

  StreamSubscription<dynamic>? _subscription;
  final _service = BankNotifyService();

  Future<bool> isNotificationAccessGranted() async {
    final granted =
        await _methodChannel.invokeMethod<bool>('isNotificationAccessGranted');
    return granted ?? false;
  }

  Future<void> openNotificationAccessSettings() async {
    await _methodChannel.invokeMethod('openNotificationAccessSettings');
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, enabled);
    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  void start() {
    if (_subscription != null) return;
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final rawText = '${map['title'] ?? ''}\n${map['text'] ?? ''}';
      _handleRawText(rawText);
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleRawText(String rawText) async {
    final parsed = parseBankNotification(rawText);
    if (parsed == null) return;

    final key = _service.buildDedupKey(parsed);
    if (await _service.isAlreadyProcessed(key)) return;

    final cards = await ApiClient().fetchCards();
    final card = _service.matchCardByLastFour(cards, parsed.cardLastFour);

    await _service.createTransaction(parsed,
        cardId: card?.id, rawText: rawText);
    await _service.markProcessed(key);
  }
}
