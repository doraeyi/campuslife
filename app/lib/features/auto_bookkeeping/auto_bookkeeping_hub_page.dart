import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AutoBookkeepingHubPage extends StatelessWidget {
  const AutoBookkeepingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 16),
              child: Text('自動記帳', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  ListTile(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0EA5E9)),
                    title: const Text('財政部發票 CSV 匯入'),
                    subtitle: const Text('匯出手機條碼消費明細，批次建立交易'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => context.push('/settings/einvoice-import'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF0EA5E9)),
                    title: const Text('銀行通知記帳'),
                    subtitle: const Text('截圖銀行 LINE 消費通知，自動辨識記帳'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => context.push('/settings/bank-notify'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF0EA5E9)),
                    title: const Text('班表匯入'),
                    subtitle: const Text('LINE 傳來的排班表照片，辨識後可編輯確認'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => context.push('/settings/roster-import'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
