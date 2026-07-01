import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/job.dart';
import '../providers/settings_provider.dart';

const _kJobColors = [
  '#6366F1',
  '#F59E0B',
  '#10B981',
  '#EF4444',
  '#3B82F6',
  '#8B5CF6',
  '#EC4899',
  '#06B6D4',
];

Color _hexToColor(String hex) {
  final v = hex.replaceFirst('#', '');
  return Color(int.parse('FF$v', radix: 16));
}

void showJobFormSheet(BuildContext context, {Job? job}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => JobFormSheet(job: job),
  );
}

class JobFormSheet extends HookConsumerWidget {
  const JobFormSheet({super.key, this.job});

  final Job? job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = job != null;
    final initialRate = isEditing
        ? (job!.payType == PayType.hourly
            ? job!.hourlyRate?.toStringAsFixed(0) ?? ''
            : job!.monthlySalary?.toStringAsFixed(0) ?? '')
        : '';

    final nameCtrl = useTextEditingController(text: job?.name ?? '');
    final rateCtrl = useTextEditingController(text: initialRate);
    final paydayCtrl = useTextEditingController(text: job?.payday?.toString() ?? '');
    final laborCtrl = useTextEditingController(
        text: isEditing ? job!.laborInsuranceFee.toStringAsFixed(0) : '0');
    final healthCtrl = useTextEditingController(
        text: isEditing ? job!.healthInsuranceFee.toStringAsFixed(0) : '0');

    final selectedColor = useState(isEditing ? colorToHex(job!.color) : _kJobColors.first);
    final payType = useState(job?.payType ?? PayType.hourly);
    final isSaving = useState(false);

    useListenable(nameCtrl);
    useListenable(rateCtrl);
    useListenable(paydayCtrl);

    final canSave =
        nameCtrl.text.trim().isNotEmpty &&
        rateCtrl.text.trim().isNotEmpty &&
        paydayCtrl.text.trim().isNotEmpty;

    Future<void> save() async {
      isSaving.value = true;
      try {
        final notifier = ref.read(settingsJobsProvider.notifier);
        final name = nameCtrl.text.trim();
        final color = selectedColor.value;
        final pt = payType.value;
        final rate = double.tryParse(rateCtrl.text.trim());
        final payday = int.tryParse(paydayCtrl.text.trim());
        final labor = double.tryParse(laborCtrl.text.trim()) ?? 0;
        final health = double.tryParse(healthCtrl.text.trim()) ?? 0;

        if (isEditing) {
          await notifier.updateJob(
            id: job!.id,
            name: name,
            colorHex: color,
            payType: pt,
            rate: rate,
            payday: payday,
            laborInsuranceFee: labor,
            healthInsuranceFee: health,
          );
        } else {
          await notifier.addJob(
            name: name,
            colorHex: color,
            payType: pt,
            rate: rate,
            payday: payday,
            laborInsuranceFee: labor,
            healthInsuranceFee: health,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    final mq = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mq.viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
              isEditing ? '編輯工作' : '新增工作',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 公司名稱
            TextField(
              controller: nameCtrl,
              autofocus: !isEditing,
              decoration: _inputDeco('公司名稱'),
            ),
            const SizedBox(height: 16),

            // 顏色
            const Text('顏色', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: _kJobColors.map((hex) {
                final selected = selectedColor.value == hex;
                return GestureDetector(
                  onTap: () => selectedColor.value = hex,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: selected ? 36 : 30,
                    height: selected ? 36 : 30,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [BoxShadow(color: _hexToColor(hex).withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 薪資類型
            const Text('薪資類型', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: '時薪',
                    selected: payType.value == PayType.hourly,
                    onTap: () => payType.value = PayType.hourly,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeButton(
                    label: '月薪',
                    selected: payType.value == PayType.monthly,
                    onTap: () => payType.value = PayType.monthly,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 薪資金額
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(
                payType.value == PayType.hourly ? '時薪金額' : '月薪金額',
                prefix: '\$ ',
              ),
            ),
            const SizedBox(height: 16),

            // 發薪日
            TextField(
              controller: paydayCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('發薪日', suffix: '號'),
            ),
            const SizedBox(height: 16),

            // 勞保 + 健保
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: laborCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('勞保自付額', prefix: '\$ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: healthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('健保自付額', prefix: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 儲存
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

InputDecoration _inputDeco(String label, {String? prefix, String? suffix}) {
  return InputDecoration(
    labelText: label,
    prefixText: prefix,
    suffixText: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBBF24) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: const Color(0xFFF59E0B)) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
