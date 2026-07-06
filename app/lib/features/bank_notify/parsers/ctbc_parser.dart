import 'bank_notification_parser.dart';

/// Parses 中國信託 (CTBC) LINE official-account consumption cards.
///
/// In the field, OCR on this card layout has turned out to badly mangle the
/// Chinese field labels ("卡末四碼", "商店名稱", "交易時間" come out as near
/// gibberish like "5:" / "3 :"), while the Latin/digit content ("NT$19",
/// "2999", "2026/07/05 18:59") survives fine. So instead of anchoring on
/// label text, this pulls fields out structurally:
///   - amount: "NT$" (or OCR's "NT S"/"NTS") followed by digits
///   - time: a "yyyy/MM/dd HH:mm"-shaped date, wherever it appears
///   - card last four: the first standalone 4-digit run that isn't the
///     date's year
/// Label-based matches are still tried first since they're more precise
/// when OCR happens to get them right.
class CtbcParser implements BankNotificationParser {
  @override
  String get bankId => 'ctbc';

  static final _cardLastFourLabeled = RegExp(r'卡末四碼[:：]?\s*(\d{4})');
  static final _merchantLabeled = RegExp(r'商店名稱[:：]?\s*(.+)');
  static final _dateTime = RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\s+(\d{1,2}):(\d{2})');
  // OCR 常把 "$" 認成 "S"，NT 跟金額之間的符號盡量放寬
  static final _amount = RegExp(r'NT\s*[\$Ss]?\s*(\d[\d,]*(?:\.\d+)?)');

  @override
  bool matches(String rawText) {
    if (!_amount.hasMatch(rawText)) return false;
    final time = _parseDateTime(rawText);
    return _cardLastFourLabeled.hasMatch(rawText) ||
        _findStandaloneFourDigits(rawText, excludeYear: time?.year.toString()) != null;
  }

  @override
  ParsedBankTransaction? parse(String rawText) {
    final amountMatch = _amount.firstMatch(rawText);
    if (amountMatch == null) return null;
    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;

    final time = _parseDateTime(rawText);
    final cardLastFour = _cardLastFourLabeled.firstMatch(rawText)?.group(1) ??
        _findStandaloneFourDigits(rawText, excludeYear: time?.year.toString());
    final merchant = _merchantLabeled.firstMatch(rawText)?.group(1)?.trim() ?? '中國信託消費';

    return ParsedBankTransaction(
      bankId: bankId,
      amount: amount,
      merchant: merchant,
      time: time,
      cardLastFour: cardLastFour,
    );
  }

  DateTime? _parseDateTime(String rawText) {
    final m = _dateTime.firstMatch(rawText);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    } catch (_) {
      return null;
    }
  }

  /// First run of exactly 4 digits, split on any non-digit separator so it
  /// doesn't accidentally grab part of a longer number — skipping the
  /// date's year if one was found, since that's also 4 digits.
  String? _findStandaloneFourDigits(String rawText, {String? excludeYear}) {
    for (final token in rawText.split(RegExp(r'[^\d]+'))) {
      if (token.length == 4 && token != excludeYear) return token;
    }
    return null;
  }
}
