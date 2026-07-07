import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/statement.dart';
import '../../services/api_client.dart';
import 'providers/settings_provider.dart';
import 'widgets/statement_form_sheet.dart';

const _kAmber = Color(0xFFFBBF24);
const _kRose = Color(0xFFF43F5E);
const _kGreen = Color(0xFF10B981);
const _kGrey = Color(0xFF6B7280);

Color _statusColor(String status) {
  switch (status) {
    case '已繳清':
      return _kGreen;
    case '逾期':
      return _kRose;
    default:
      return _kGrey;
  }
}

Widget _statusBadge(String status) {
  final color = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      status,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class CreditAccountDetailPage extends ConsumerWidget {
  const CreditAccountDetailPage({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final accountsAsync = ref.watch(creditAccountsProvider);
    final account = accountsAsync.value?.where((a) => a.id == accountId).firstOrNull;
    final availableAsync = ref.watch(creditAccountAvailableProvider(accountId));
    final statementsAsync = ref.watch(statementsProvider(accountId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(account?.name ?? '額度群組')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStatementFormSheet(context, creditAccountId: accountId),
        icon: const Icon(Icons.add),
        label: const Text('新增帳單'),
        backgroundColor: _kAmber,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creditAccountAvailableProvider(accountId));
          ref.invalidate(statementsProvider(accountId));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            availableAsync.when(
              data: (avail) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('可用額度', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(avail.availableCredit),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可用 ${fmt.format(avail.availableCredit)}／額度 ${fmt.format(avail.creditLimit)}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('載入可用額度失敗：$e', style: const TextStyle(color: _kRose)),
            ),
            const SizedBox(height: 24),
            Text('帳單', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            statementsAsync.when(
              data: (statements) {
                if (statements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('尚無帳單，點右下角「新增帳單」開始建立', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  );
                }
                return Column(
                  children: statements
                      .map((s) => _StatementTile(accountId: accountId, statement: s, fmt: fmt))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('載入帳單失敗：$e', style: const TextStyle(color: _kRose)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementTile extends ConsumerWidget {
  const _StatementTile({required this.accountId, required this.statement, required this.fmt});

  final int accountId;
  final Statement statement;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${dateFmt.format(statement.periodStart)} ~ ${dateFmt.format(statement.periodEnd)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              _statusBadge(statement.status),
            ],
          ),
          const SizedBox(height: 6),
          Text('到期日 ${dateFmt.format(statement.dueDate)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(statement.paidAmount)} / ${fmt.format(statement.statementAmount)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: _kGrey),
                onPressed: () => showStatementFormSheet(context, creditAccountId: accountId, statement: statement),
                tooltip: '編輯',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: _kRose),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('刪除帳單'),
                      content: const Text('確定要刪除這張帳單嗎？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('刪除', style: TextStyle(color: _kRose)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ApiClient().deleteStatement(statement.id);
                    ref.invalidate(statementsProvider(accountId));
                    ref.invalidate(creditAccountAvailableProvider(accountId));
                  }
                },
                tooltip: '刪除',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
