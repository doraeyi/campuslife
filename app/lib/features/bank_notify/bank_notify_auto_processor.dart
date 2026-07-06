import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../models/pending_screenshot.dart';
import '../../services/api_client.dart';
import 'parsers/bank_notification_parser.dart';
import 'parsers/parser_registry.dart';

/// A pending screenshot that's been downloaded and OCR'd, ready for the user
/// to review. [parsed] is null when OCR ran but nothing recognizable came
/// out of it -- that item falls back to the manual screenshot-import flow.
class BankNotifyPreview {
  const BankNotifyPreview(
      {required this.item, required this.parsed, required this.rawText});
  final PendingScreenshot item;
  final ParsedBankTransaction? parsed;
  final String rawText;
}

/// Downloads and OCRs pending bank-notify screenshots so the review page can
/// show the user what would get recorded before anything actually happens.
///
/// This used to also auto-create the transaction the moment parsing
/// succeeded, with no confirmation step. That turned out to be the wrong
/// trade-off in practice: when something went wrong partway (a stale local
/// de-dup entry, a flaky network call, OCR misreading a field), the failure
/// was invisible -- nothing was recorded and nothing told the user why. Now
/// this only ever produces a preview; creating the transaction is always an
/// explicit tap on "一鍵入帳" in the UI.
class BankNotifyAutoProcessor {
  Future<BankNotifyPreview> loadPreview(PendingScreenshot item) async {
    try {
      final bytes = await ApiClient().fetchPendingScreenshotImage(item.id);
      final tempDir = await Directory.systemTemp.createTemp('yiwallet_preview');
      final file = File('${tempDir.path}/${item.id}.jpg');
      await file.writeAsBytes(bytes);

      final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      await recognizer.close();

      return BankNotifyPreview(
        item: item,
        parsed: parseBankNotification(result.text),
        rawText: result.text,
      );
    } catch (e) {
      return BankNotifyPreview(item: item, parsed: null, rawText: '辨識時發生錯誤：$e');
    }
  }
}
