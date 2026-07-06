import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/einvoice.dart';
import '../../services/api_client.dart';
import '../settings/providers/settings_provider.dart';

class EinvoiceImportPage extends HookConsumerWidget {
  const EinvoiceImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final cards = cardsAsync.value ?? [];

    final selectedCardId = useState<int?>(null);
    final pickedFile = useState<File?>(null);
    final importing = useState(false);
    final result = useState<EinvoiceImportResult?>(null);
    final error = useState<String?>(null);

    Future<void> pickFile() async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (picked == null || picked.files.single.path == null) return;
      pickedFile.value = File(picked.files.single.path!);
      result.value = null;
      error.value = null;
    }

    Future<void> import() async {
      if (pickedFile.value == null) return;
      importing.value = true;
      error.value = null;
      try {
        final res = await ApiClient().importEinvoiceCsv(
          pickedFile.value!,
          cardId: selectedCardId.value,
        );
        result.value = res;
      } catch (e) {
        error.value = '$e';
      } finally {
        importing.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('財政部發票 CSV 匯入')),
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
                    Text('如何取得 CSV 檔案', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      '1. 前往財政部電子發票整合服務平台，登入手機條碼專區\n'
                      '2. 進入載具消費發票查詢，選擇要匯出的月份\n'
                      '3. 使用「匯出發票」功能下載 CSV 檔案\n'
                      '4. 回到這裡選擇該檔案匯入',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('記到哪張卡片（選填）', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: selectedCardId.value,
                decoration: const InputDecoration(
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
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: importing.value ? null : pickFile,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(pickedFile.value == null
                    ? '選擇 CSV 檔案'
                    : pickedFile.value!.path.split(RegExp(r'[\\/]')).last),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (pickedFile.value == null || importing.value) ? null : import,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: importing.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('開始匯入'),
              ),
              if (error.value != null) ...[
                const SizedBox(height: 16),
                Text(error.value!, style: const TextStyle(color: Colors.red)),
              ],
              if (result.value != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('匯入完成：新增 ${result.value!.imported} 筆，略過 ${result.value!.skipped} 筆（重複）',
                          style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                      if (result.value!.errors.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...result.value!.errors.map((e) => Text(
                              '⚠ $e',
                              style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
