import 'bank_notification_parser.dart';

/// Parses 中國信託 (CTBC) LINE official-account consumption cards, e.g.:
///
///   LINE Pay簽帳卡
///   NT$2
///   卡末四碼： 2999
///   交易時間： 2026/07/05 22:44
///   商店名稱： 統一超商－八里
///
/// Field labels are consistent whether the text comes from OCR'ing a
/// screenshot of the chat bubble, or from the (often-truncated) Android
/// notification banner text — this same set of patterns is tried against
/// both.
class CtbcParser implements BankNotificationParser {
  @override
  String get bankId => 'ctbc';

  static final _cardLastFour = RegExp(r'卡末四碼[:：]?\s*(\d{4})');
  static final _merchant = RegExp(r'商店名稱[:：]?\s*(.+)');
  static final _time = RegExp(r'交易時間[:：]?\s*([\d/\-]+\s+[\d:]+)');
  // OCR 常把 "$" 認成 "S"，NT 跟金額之間的符號盡量放寬
  static final _amount = RegExp(r'NT\s*[\$Ss]?\s*(\d[\d,]*(?:\.\d+)?)');

  // 不要求比對到「中國信託」「LINE Pay簽帳卡」這類招牌文字——OCR 對這些字
  // 常常斷行、加空格、或把字元認錯，反而讓整組辨識直接失敗。改用「卡末四碼」
  // +「商店名稱」這兩個欄位標籤同時出現來判斷，對這張卡片式訊息來說已經夠獨特。
  @override
  bool matches(String rawText) {
    return _cardLastFour.hasMatch(rawText) && _merchant.hasMatch(rawText);
  }

  @override
  ParsedBankTransaction? parse(String rawText) {
    final amountMatch = _amount.firstMatch(rawText);
    if (amountMatch == null) return null;
    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;

    final merchant = _merchant.firstMatch(rawText)?.group(1)?.trim() ?? '中國信託消費';
    final cardLastFour = _cardLastFour.firstMatch(rawText)?.group(1);
    final time = _parseTime(_time.firstMatch(rawText)?.group(1));

    return ParsedBankTransaction(
      bankId: bankId,
      amount: amount,
      merchant: merchant,
      time: time,
      cardLastFour: cardLastFour,
    );
  }

  DateTime? _parseTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\s+(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return null;
    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
    } catch (_) {
      return null;
    }
  }
}
