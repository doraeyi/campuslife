import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import 'bank_notify_service.dart';
import 'parsers/parser_registry.dart';

/// Runs whenever the app is opened (see [bankNotifyPendingCountProvider]):
/// downloads any screenshots forwarded to the LINE bot since last time, OCRs
/// them on-device, and for anything that parses cleanly, auto-creates the
/// transaction right away, fires a local notification, and tells the backend
/// to push a LINE confirmation message — no manual "處理" tap needed. Items
/// that fail to parse are left in the pending list for the existing manual
/// screenshot-import flow to handle.
class BankNotifyAutoProcessor {
  final _service = BankNotifyService();

  /// Returns the number of pending screenshots still left after processing
  /// (i.e. the ones that couldn't be auto-parsed).
  Future<int> processAll() async {
    final api = ApiClient();
    final pending = await api.fetchPendingScreenshots();
    if (pending.isEmpty) return 0;

    final cards = await api.fetchCards();
    var remaining = pending.length;

    for (final item in pending) {
      try {
        final bytes = await api.fetchPendingScreenshotImage(item.id);
        final tempDir = await Directory.systemTemp.createTemp('yiwallet_auto');
        final file = File('${tempDir.path}/${item.id}.jpg');
        await file.writeAsBytes(bytes);

        final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
        final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
        await recognizer.close();

        final parsed = parseBankNotification(result.text);
        if (parsed == null) continue;

        final key = _service.buildDedupKey(parsed);
        if (await _service.isAlreadyProcessed(key)) {
          // 已經記過帳了，只是還沒清掉這筆待確認紀錄
          await api.deletePendingScreenshot(item.id);
          remaining--;
          continue;
        }

        final card = _service.matchCardByLastFour(cards, parsed.cardLastFour);
        await _service.createTransaction(parsed, cardId: card?.id, rawText: result.text);
        await _service.markProcessed(key);

        final summary = '${parsed.merchant} -\$${parsed.amount.toStringAsFixed(0)}'
            '${card != null ? ' ${card.name}' : ''}';
        await NotificationService().showBankNotifyResult(
          parsed.merchant,
          parsed.amount,
        );
        await api.notifyPendingScreenshotDone(item.id, '✅ 已自動記帳：$summary');
        remaining--;
      } catch (_) {
        // 這張處理失敗（下載失敗、辨識出錯等）就留著，讓使用者之後手動處理
      }
    }

    return remaining;
  }
}
