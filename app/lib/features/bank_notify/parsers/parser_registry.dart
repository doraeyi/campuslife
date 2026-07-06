import 'bank_notification_parser.dart';
import 'ctbc_parser.dart';

/// All supported bank parsers. Adding a new bank only means writing a new
/// `BankNotificationParser` implementation and registering it here — nothing
/// else in the app needs to change.
final List<BankNotificationParser> bankNotificationParsers = [
  CtbcParser(),
];

ParsedBankTransaction? parseBankNotification(String rawText) {
  for (final parser in bankNotificationParsers) {
    if (parser.matches(rawText)) {
      final parsed = parser.parse(rawText);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
