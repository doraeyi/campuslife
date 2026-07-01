import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import 'add_transaction_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _api = ApiClient();
  List<AppCard> _cards = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  int _cardPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.fetchCards(),
        _api.fetchTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _cards = results[0] as List<AppCard>;
          _transactions = results[1] as List<Transaction>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTransaction(Transaction tx) async {
    await _api.deleteTransaction(tx.id);
    await _load();
  }

  Future<void> _showUpdateBalance(AppCard card) async {
    final ctrl = TextEditingController(
      text: card.balance?.toStringAsFixed(0) ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新餘額'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$  ', hintText: '輸入目前餘額'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final val = double.tryParse(ctrl.text);
      if (val != null) {
        await _api.updateCardBalance(card.id, val);
        await _load();
      }
    }
  }

  void _openAddTransaction() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddTransactionSheet(cards: _cards),
    );
    if (added == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記帳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _openAddTransaction,
            tooltip: '新增記帳',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── Card carousel ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _cards.isEmpty
                        ? _EmptyCardsHint()
                        : _CardCarousel(
                            cards: _cards,
                            currentIndex: _cardPage,
                            onPageChanged: (i) => setState(() => _cardPage = i),
                            onUpdateBalance: _showUpdateBalance,
                          ),
                  ),
                  // ── Transaction list ───────────────────────────────────
                  if (_transactions.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTransactionsHint(),
                    )
                  else
                    _TransactionSliver(
                      transactions: _transactions,
                      onDelete: _deleteTransaction,
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Card carousel ─────────────────────────────────────────────────────────────
class _CardCarousel extends StatelessWidget {
  const _CardCarousel({
    required this.cards,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onUpdateBalance,
  });

  final List<AppCard> cards;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AppCard> onUpdateBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            itemCount: cards.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => _CardTile(
              card: cards[i],
              onUpdateBalance: () => onUpdateBalance(cards[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == currentIndex ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == currentIndex
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onUpdateBalance});

  final AppCard card;
  final VoidCallback onUpdateBalance;

  @override
  Widget build(BuildContext context) {
    final base = _parseColor(card.color);
    final isEasycard = card.type == 'easycard';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [base, _darken(base, 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (card.bank != null)
                      Text(
                        card.bank!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                if (isEasycard)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                    tooltip: '更新餘額',
                    onPressed: onUpdateBalance,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              card.balance != null
                  ? NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(card.balance)
                  : '未設定餘額',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _cardTypeLabel(card.type),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                if (card.lastFour != null)
                  Text(
                    '•••• ${card.lastFour}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction sliver ────────────────────────────────────────────────────────
class _TransactionSliver extends StatelessWidget {
  const _TransactionSliver({
    required this.transactions,
    required this.onDelete,
  });

  final List<Transaction> transactions;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    // Group by date label
    final groups = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final key = _dateLabel(tx.createdAt);
      (groups[key] ??= []).add(tx);
    }
    final keys = groups.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final label = keys[i];
          final txns = groups[label]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...txns.map(
                (tx) => Dismissible(
                  key: ValueKey(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Theme.of(ctx).colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete_rounded,
                      color: Theme.of(ctx).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('刪除交易'),
                        content: Text('確定刪除「${tx.description}」？餘額將還原。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('刪除'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => onDelete(tx),
                  child: _TransactionTile(tx: tx),
                ),
              ),
            ],
          );
        },
        childCount: keys.length,
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.isExpense;
    final amountStr =
        '${isExpense ? '-' : '+'}\$${NumberFormat('#,##0').format(tx.amount.abs())}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: isExpense
            ? Theme.of(context).colorScheme.errorContainer
            : const Color(0xFFD1FAE5),
        child: Icon(
          isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: isExpense
              ? Theme.of(context).colorScheme.error
              : const Color(0xFF059669),
        ),
      ),
      title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: tx.card != null
          ? Text(tx.card!.name, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Text(
        amountStr,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isExpense
              ? Theme.of(context).colorScheme.error
              : const Color(0xFF059669),
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────
class _EmptyCardsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.credit_card_off_rounded,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            '還沒有卡片，去設定新增一張吧',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactionsHint extends StatelessWidget {
  const _EmptyTransactionsHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            '還沒有記帳，點右上角 + 開始吧',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Color _parseColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

String _cardTypeLabel(String type) => switch (type) {
      'debit' => '金融卡',
      'credit' => '信用卡',
      'easycard' => '悠遊卡',
      _ => type,
    };

String _dateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return '今天';
  if (d == today.subtract(const Duration(days: 1))) return '昨天';
  return DateFormat('M/d').format(dt);
}
