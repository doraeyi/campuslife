import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/roster.dart';
import '../../services/api_client.dart';
import 'parsers/roster_table_parser.dart';
import 'providers/roster_pending_provider.dart';
import 'roster_review_page.dart';

/// 排班表照片的待處理清單。跟「銀行通知記帳」不同，這裡的 OCR 猜測一律導去
/// [RosterReviewPage] 手動校正，沒有「一鍵入帳」自動路徑——表格辨識準確率
/// 遠不如單筆通知，不該讓使用者跳過確認。
class RosterImportPage extends HookConsumerWidget {
  const RosterImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = useState<List<PendingRosterPhoto>>([]);
    final loadingPending = useState(true);
    final recognizing = useState(false);
    final message = useState<String?>(null);

    Future<void> refreshPending() async {
      loadingPending.value = true;
      try {
        final list = await ApiClient().fetchPendingRosterPhotos();
        pending.value = list;
        ref.invalidate(rosterPendingCountProvider);
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

    Future<void> recognizeAndReview(File file, {int? pendingId}) async {
      recognizing.value = true;
      message.value = null;
      try {
        final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
        final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
        await recognizer.close();
        final guess = parseRosterTable(result.text);

        if (!context.mounted) return;
        final imported = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RosterReviewPage(pendingId: pendingId, guess: guess, rawText: result.text),
          ),
        );
        if (imported == true) await refreshPending();
      } catch (e) {
        message.value = '辨識失敗：$e';
      } finally {
        recognizing.value = false;
      }
    }

    Future<void> processPending(PendingRosterPhoto item) async {
      recognizing.value = true;
      message.value = null;
      try {
        final bytes = await ApiClient().fetchPendingRosterPhotoImage(item.id);
        final tempDir = await Directory.systemTemp.createTemp('yiwallet_roster');
        final file = File('${tempDir.path}/${item.id}.jpg');
        await file.writeAsBytes(bytes);
        await recognizeAndReview(file, pendingId: item.id);
      } catch (e) {
        recognizing.value = false;
        message.value = '下載照片失敗：$e';
      }
    }

    Future<void> pickAndRecognize() async {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      await recognizeAndReview(File(image.path));
    }

    Future<void> deletePending(PendingRosterPhoto item) async {
      await ApiClient().deletePendingRosterPhoto(item.id);
      await refreshPending();
    }

    const howToUseText =
        '在 LINE 裡先傳文字「班表」給 YiWallet 的 Bot（跟平常「茶葉蛋 10」記帳是同一個聊天室），'
        '10 分鐘內把排班表照片傳過去，就會出現在下面的待處理清單。也可以直接從相簿選照片匯入。'
        '辨識完一律會先進到校正畫面，確認沒問題再送出，不會自動寫入。';

    return Scaffold(
      appBar: AppBar(
        title: const Text('班表匯入'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '怎麼用',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('怎麼用'),
                content: const Text(howToUseText, style: TextStyle(height: 1.5)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('待處理照片（LINE 轉傳）', style: TextStyle(fontWeight: FontWeight.w500)),
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
                  child: Text('目前沒有待處理的照片', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              else
                ...pending.value.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.table_chart_outlined),
                        title: Text(DateFormat('MM/dd HH:mm').format(item.createdAt.toLocal())),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: recognizing.value ? null : () => deletePending(item),
                            ),
                            FilledButton(
                              onPressed: recognizing.value ? null : () => processPending(item),
                              child: const Text('辨識校正'),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: recognizing.value ? null : pickAndRecognize,
                icon: const Icon(Icons.image_search_rounded),
                label: const Text('從相簿選擇照片'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              if (recognizing.value) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (message.value != null) ...[
                const SizedBox(height: 16),
                Text(message.value!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
