import 'package:shared_preferences/shared_preferences.dart';

import '../../models/card_model.dart';
import '../../models/transaction.dart';
import '../../services/api_client.dart';
import 'parsers/bank_notification_parser.dart';

/// Shared logic used by both the screenshot+OCR importer (B4) and the
/// Android notification listener (B5) — card matching, de-duplication and
/// transaction creation, so both entry points behave identically once they
/// have a [ParsedBankTransaction] in hand.
class BankNotifyService {
  static const _processedKeysPrefKey = 'bank_notify_processed_keys';
  static const _maxTrackedKeys = 500;

  /// Finds the card whose last four digits match the parsed notification.
  /// Returns null if there's no match (or nothing to match against), in
  /// which case the caller should ask the user to pick a card manually.
  AppCard? matchCardByLastFour(List<AppCard> cards, String? cardLastFour) {
    if (cardLastFour == null) return null;
    for (final card in cards) {
      if (card.lastFour == cardLastFour) return card;
    }
    return null;
  }

  String buildDedupKey(ParsedBankTransaction parsed) {
    final minuteBucket = parsed.time != null
        ? '${parsed.time!.year}${parsed.time!.month}${parsed.time!.day}${parsed.time!.hour}${parsed.time!.minute}'
        : 'no-time';
    return '${parsed.bankId}|${parsed.amount}|${parsed.cardLastFour ?? '-'}|$minuteBucket';
  }

  Future<bool> isAlreadyProcessed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_processedKeysPrefKey) ?? [];
    return keys.contains(key);
  }

  Future<void> markProcessed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_processedKeysPrefKey) ?? [];
    if (keys.contains(key)) return;
    keys.add(key);
    final trimmed = keys.length > _maxTrackedKeys
        ? keys.sublist(keys.length - _maxTrackedKeys)
        : keys;
    await prefs.setStringList(_processedKeysPrefKey, trimmed);
  }

  /// The de-dup list lives purely on-device and has no idea whether the
  /// transaction it once pointed at still exists on the backend (e.g. it got
  /// deleted, or the local storage survived a reinstall) — so a stale entry
  /// can silently swallow a screenshot that should have been recorded again.
  /// This clears that local list so the next forward is treated as fresh.
  Future<void> clearProcessedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_processedKeysPrefKey);
  }

  Future<Transaction> createTransaction(
    ParsedBankTransaction parsed, {
    int? cardId,
    String? rawText,
  }) {
    final debugNote = rawText != null && rawText.length > 200 ? rawText.substring(0, 200) : rawText;
    return ApiClient().createTransaction(
      cardId: cardId,
      amount: parsed.amount,
      description: parsed.merchant,
      transactionType: 'expense',
      category: 'other',
      note: debugNote ?? '銀行通知自動記帳',
    );
  }
}
