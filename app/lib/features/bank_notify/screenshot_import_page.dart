import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/pending_screenshot.dart';
import '../../services/api_client.dart';
import '../settings/providers/settings_provider.dart';
import 'android_notification_listener.dart';
import 'bank_notify_service.dart';
import 'parsers/bank_notification_parser.dart';
import 'parsers/parser_registry.dart';

class ScreenshotImportPage extends HookConsumerWidget {
  const ScreenshotImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final cards = cardsAsync.value ?? [];
    final service = useMemoized(BankNotifyService.new);

    final pickedImage = useState<File?>(null);
    final activePendingId = useState<int?>(null);
    final recognizing = useState(false);
    final recognizedText = useState<String?>(null);
    final parsed = useState<ParsedBankTransaction?>(null);
    final selectedCardId = useState<int?>(null);
    final amountCtrl = useTextEditingController();
    final merchantCtrl = useTextEditingController();
    final creating = useState(false);
    final message = useState<String?>(null);

    final pending = useState<List<PendingScreenshot>>([]);
    final loadingPending = useState(true);

    Future<void> refreshPending() async {
      loadingPending.value = true;
      try {
        pending.value = await ApiClient().fetchPendingScreenshots();
      } catch (_) {
        // 忽略：使用者沒綁定 LINE 或暫時連不上都不影響其他功能
      } finally {
        loadingPending.value = false;
      }
    }

    useEffect(() {
      refreshPending();
      return null;
    }, []);

    Future<void> recognizeFile(File file) async {
      pickedImage.value = file;
      recognizing.value = true;
      recognizedText.value = null;
      parsed.value = null;
      message.value = null;

      try {
        final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
        final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
        await recognizer.close();
        recognizedText.value = result.text;

        final match = parseBankNotification(result.text);
        parsed.value = match;
        if (match != null) {
          amountCtrl.text = match.amount.toStringAsFixed(0);
          merchantCtrl.text = match.merchant;
          final matchedCard = service.matchCardByLastFour(cards, match.cardLastFour);
          selectedCardId.value = matchedCard?.id;
        } else {
          message.value = '無法從這張截圖辨識出銀行消費通知，請確認截圖包含完整卡片內容（商店名稱、金額、卡末四碼）';
        }
      } catch (e) {
        message.value = '辨識失敗：$e';
      } finally {
        recognizing.value = false;
      }
    }

    Future<void> pickAndRecognize() async {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      activePendingId.value = null;
      await recognizeFile(File(image.path));
    }

    Future<void> processPending(PendingScreenshot item) async {
      recognizing.value = true;
      message.value = null;
      try {
        final bytes = await ApiClient().fetchPendingScreenshotImage(item.id);
        final tempDir = await Directory.systemTemp.createTemp('yiwallet_pending');
        final file = File('${tempDir.path}/${item.id}.jpg');
        await file.writeAsBytes(bytes);
        activePendingId.value = item.id;
        await recognizeFile(file);
      } catch (e) {
        recognizing.value = false;
        message.value = '下載截圖失敗：$e';
      }
    }

    Future<void> confirmAndCreate() async {
      final p = parsed.value;
      if (p == null) return;
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount == null) {
        message.value = '金額格式錯誤';
        return;
      }

      creating.value = true;
      message.value = null;
      try {
        final key = service.buildDedupKey(p);
        if (await service.isAlreadyProcessed(key)) {
          message.value = '這筆交易先前已經匯入過了，未重複建立';
          return;
        }

        await service.createTransaction(
          ParsedBankTransaction(
            bankId: p.bankId,
            amount: amount,
            merchant: merchantCtrl.text.trim(),
            time: p.time,
            cardLastFour: p.cardLastFour,
          ),
          cardId: selectedCardId.value,
          rawText: recognizedText.value,
        );
        await service.markProcessed(key);

        if (activePendingId.value != null) {
          await ApiClient().deletePendingScreenshot(activePendingId.value!);
          await refreshPending();
        }

        message.value = '已建立交易：${merchantCtrl.text.trim()} -\$${amount.toStringAsFixed(0)}';
        pickedImage.value = null;
        parsed.value = null;
        recognizedText.value = null;
        activePendingId.value = null;
      } catch (e) {
        message.value = '建立交易失敗：$e';
      } finally {
        creating.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('銀行通知記帳')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('怎麼用', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      '收到銀行 LINE 消費通知後，最快的方式是直接在 LINE 裡把那則卡片截圖轉傳給 YiWallet 的 '
                      'LINE Bot（跟平常「茶葉蛋 10」記帳是同一個聊天室），截圖會出現在下面的待確認清單。'
                      '也可以自己截圖後從相簿選圖匯入。目前支援：中國信託。',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              if (!kIsWeb && Platform.isAndroid) ...[
                const SizedBox(height: 16),
                const _AndroidAutoListenCard(),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('待確認截圖（LINE 轉傳）', style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: loadingPending.value ? null : refreshPending,
                  ),
                ],
              ),
              if (loadingPending.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (pending.value.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('目前沒有待確認的截圖', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              else
                ...pending.value.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: Text(DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal())),
                        trailing: FilledButton(
                          onPressed: recognizing.value ? null : () => processPending(item),
                          child: const Text('處理'),
                        ),
                      ),
                    )),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: recognizing.value ? null : pickAndRecognize,
                icon: const Icon(Icons.image_search_rounded),
                label: const Text('從相簿選擇截圖'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              if (recognizing.value) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (pickedImage.value != null && !recognizing.value) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(pickedImage.value!, height: 160, fit: BoxFit.cover),
                ),
              ],
              if (parsed.value != null) ...[
                const SizedBox(height: 20),
                const Text('確認記帳內容', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: merchantCtrl,
                  decoration: const InputDecoration(
                    labelText: '商店名稱',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '金額',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: selectedCardId.value,
                  decoration: const InputDecoration(
                    labelText: '記到哪張卡片',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('不指定卡片')),
                    ...cards.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => selectedCardId.value = v,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: creating.value ? null : confirmAndCreate,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: creating.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('確認建立交易'),
                ),
              ],
              if (message.value != null) ...[
                const SizedBox(height: 16),
                Text(message.value!, style: const TextStyle(color: Colors.red)),
              ],
              if (recognizedText.value != null && (kDebugMode || parsed.value == null)) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('辨識原文（辨識失敗時可複製回報）',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                      onPressed: () => Clipboard.setData(ClipboardData(text: recognizedText.value!)),
                      tooltip: '複製',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(recognizedText.value!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Android-only advanced option: full auto-listen via NotificationListenerService,
/// on top of the screenshot+OCR baseline above.
class _AndroidAutoListenCard extends HookWidget {
  const _AndroidAutoListenCard();

  @override
  Widget build(BuildContext context) {
    final listener = useMemoized(AndroidBankNotificationListener.new);
    final enabled = useState<bool?>(null);
    final granted = useState<bool?>(null);

    useEffect(() {
      () async {
        enabled.value = await listener.isEnabled();
        granted.value = await listener.isNotificationAccessGranted();
      }();
      return null;
    }, []);

    if (enabled.value == null) {
      return const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('開啟全自動監聽（進階）'),
        subtitle: Text(
          granted.value == true
              ? '通知使用權已開啟，收到通知會自動記帳'
              : '需要到系統設定開啟「通知使用權」才會生效',
          style: const TextStyle(fontSize: 12),
        ),
        value: enabled.value!,
        onChanged: (val) async {
          if (val && granted.value != true) {
            await listener.openNotificationAccessSettings();
            granted.value = await listener.isNotificationAccessGranted();
          }
          await listener.setEnabled(val);
          enabled.value = val;
        },
      ),
    );
  }
}
