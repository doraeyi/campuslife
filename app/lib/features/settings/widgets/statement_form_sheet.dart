import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/statement.dart';
import '../../../services/api_client.dart';
import '../providers/settings_provider.dart';

void showStatementFormSheet(
  BuildContext context, {
  required int creditAccountId,
  Statement? statement,
}) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: StatementFormSheet(creditAccountId: creditAccountId, statement: statement),
    ),
  );
}

class StatementFormSheet extends HookConsumerWidget {
  const StatementFormSheet({super.key, required this.creditAccountId, this.statement});

  final int creditAccountId;
  final Statement? statement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = statement != null;
    final now = DateTime.now();

    final periodStart = useState(statement?.periodStart ?? DateTime(now.year, now.month, 1));
    final periodEnd = useState(statement?.periodEnd ?? now);
    final statementDate = useState(statement?.statementDate ?? now);
    final dueDate = useState(statement?.dueDate ?? now.add(const Duration(days: 15)));
    final amountCtrl = useTextEditingController(
        text: statement != null ? statement!.statementAmount.toStringAsFixed(0) : '');
    final minimumDueCtrl = useTextEditingController(
        text: statement?.minimumDue != null ? statement!.minimumDue!.toStringAsFixed(0) : '');
    final isSaving = useState(false);

    useListenable(amountCtrl);
    final canSave = amountCtrl.text.trim().isNotEmpty;

    Future<void> pickDate(ValueNotifier<DateTime> target) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: target.value,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) target.value = picked;
    }

    Future<void> save() async {
      isSaving.value = true;
      try {
        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
        final minimumDue = minimumDueCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(minimumDueCtrl.text.trim());
        if (isEditing) {
          await ApiClient().updateStatement(
            statement!.id,
            creditAccountId: creditAccountId,
            periodStart: periodStart.value,
            periodEnd: periodEnd.value,
            statementDate: statementDate.value,
            dueDate: dueDate.value,
            statementAmount: amount,
            minimumDue: minimumDue,
          );
        } else {
          await ApiClient().createStatement(
            creditAccountId: creditAccountId,
            periodStart: periodStart.value,
            periodEnd: periodEnd.value,
            statementDate: statementDate.value,
            dueDate: dueDate.value,
            statementAmount: amount,
            minimumDue: minimumDue,
          );
        }
        ref.invalidate(statementsProvider(creditAccountId));
        ref.invalidate(creditAccountAvailableProvider(creditAccountId));
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    Widget dateField(String label, ValueNotifier<DateTime> target) {
      return Expanded(
        child: InkWell(
          onTap: () => pickDate(target),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            child: Text(DateFormat('yyyy-MM-dd').format(target.value)),
          ),
        ),
      );
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
              isEditing ? '編輯帳單' : '新增帳單',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            const Text('帳單期間', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Row(
              children: [
                dateField('起', periodStart),
                const SizedBox(width: 12),
                dateField('迄', periodEnd),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                dateField('結帳日', statementDate),
                const SizedBox(width: 12),
                dateField('繳款截止日', dueDate),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '帳單金額',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: minimumDueCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '最低應繳（選填）',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
