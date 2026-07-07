import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/credit_account.dart';
import '../providers/settings_provider.dart';

void showCreditAccountFormSheet(BuildContext context, {CreditAccount? account}) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: CreditAccountFormSheet(account: account),
    ),
  );
}

class CreditAccountFormSheet extends HookConsumerWidget {
  const CreditAccountFormSheet({super.key, this.account});

  final CreditAccount? account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = account != null;
    final nameCtrl = useTextEditingController(text: account?.name ?? '');
    final limitCtrl = useTextEditingController(
        text: account != null ? account!.creditLimit.toStringAsFixed(0) : '');
    final billingDayCtrl = useTextEditingController(text: account?.billingDay?.toString() ?? '');
    final dueDayCtrl = useTextEditingController(text: account?.dueDay?.toString() ?? '');
    final selectedBankId = useState<int?>(account?.bankId);
    final isSaving = useState(false);

    useListenable(nameCtrl);
    useListenable(limitCtrl);
    final banksAsync = ref.watch(banksProvider);

    final canSave = nameCtrl.text.trim().isNotEmpty &&
        limitCtrl.text.trim().isNotEmpty &&
        selectedBankId.value != null;

    Future<void> save() async {
      isSaving.value = true;
      try {
        final notifier = ref.read(creditAccountsProvider.notifier);
        final name = nameCtrl.text.trim();
        final creditLimit = double.tryParse(limitCtrl.text.trim()) ?? 0;
        final billingDay = int.tryParse(billingDayCtrl.text.trim());
        final dueDay = int.tryParse(dueDayCtrl.text.trim());
        if (isEditing) {
          await notifier.updateCreditAccount(
            account!.id,
            bankId: selectedBankId.value!,
            name: name,
            creditLimit: creditLimit,
            billingDay: billingDay,
            dueDay: dueDay,
          );
        } else {
          await notifier.addCreditAccount(
            bankId: selectedBankId.value!,
            name: name,
            creditLimit: creditLimit,
            billingDay: billingDay,
            dueDay: dueDay,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232329) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: mq.viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? '編輯信用額度' : '新增信用額度',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            const Text('銀行', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            banksAsync.when(
              data: (banks) => banks.isEmpty
                  ? const Text('還沒有建立任何銀行，請先到上面新增銀行',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))
                  : DropdownButtonFormField<int>(
                      initialValue: selectedBankId.value,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      items: banks
                          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (v) => selectedBankId.value = v,
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('載入銀行失敗：$e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '額度群組名稱（如：中信信用帳戶）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '信用額度',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: billingDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '結帳日（選填）',
                      suffixText: '號',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '繳款日（選填）',
                      suffixText: '號',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (canSave && !isSaving.value) ? save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isSaving.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('儲存', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
