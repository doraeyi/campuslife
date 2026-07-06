class ParsedBankTransaction {
  final String bankId;
  final double amount;
  final String merchant;
  final DateTime? time;
  final String? cardLastFour;

  const ParsedBankTransaction({
    required this.bankId,
    required this.amount,
    required this.merchant,
    this.time,
    this.cardLastFour,
  });
}

/// Parses raw text captured from a bank's LINE official-account message —
/// either OCR'd from a screenshot of the chat bubble, or read straight from
/// an Android notification banner. Both inputs are handled by the same
/// interface so the rest of the app doesn't care where the text came from.
abstract class BankNotificationParser {
  String get bankId; // e.g. "ctbc"

  bool matches(String rawText);

  ParsedBankTransaction? parse(String rawText);
}
