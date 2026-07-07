import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import 'add_transaction_sheet.dart';
import 'edit_transaction_sheet.dart';

// 用來從其他頁面（例如首頁圓環）帶著目前範圍跳轉過來，決定一開始要看哪個範圍的紀錄
class WalletFilter {
  const WalletFilter({this.cardId, this.cashOnly = false});
  final int? cardId;
  final bool cashOnly;
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, this.filter});
  final WalletFilter? filter;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _api = ApiClient();
  late final PageController _cardPageController;
  List<AppCard> _cards = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  int _cardPage = 0;
  late String _scope; // 'all' | 'cash' | 'card_<id>'
  bool _scopeInitialized = false;

  @override
  void initState() {
    super.initState();
    _cardPageController = PageController(viewportFraction: 0.88);
    if (widget.filter?.cashOnly == true) {
      _scope = 'cash';
    } else if (widget.filter?.cardId != null) {
      _scope = 'card_${widget.filter!.cardId}';
    } else {
      _scope = 'all';
    }
    _load();
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    super.dispose();
  }

  List<Transaction> get _visibleTransactions {
    if (_scope == 'all') return _transactions;
    if (_scope == 'cash') {
      return _transactions.where((t) => t.cardId == null).toList();
    }
    final id = int.tryParse(_scope.substring('card_'.length));
    return _transactions.where((t) => t.cardId == id).toList();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.fetchCards(),
        _api.fetchTransactions(),
      ]);
      if (mounted) {
        final cards = results[0] as List<AppCard>;
        setState(() {
          _cards = cards;
          _transactions = results[1] as List<Transaction>;
          _loading = false;
          if (!_scopeInitialized) {
            _scopeInitialized = true;
            if (_scope.startsWith('card_')) {
              final id = int.parse(_scope.substring('card_'.length));
              final index = cards.indexWhere((c) => c.id == id);
              if (index >= 0) {
                _cardPage = index;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_cardPageController.hasClients) {
                    _cardPageController.jumpToPage(index);
                  }
                });
              }
            }
          }
        });
        await NotificationService().checkCreditCardDueDates(cards);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTransaction(Transaction tx) async {
    await _api.deleteTransaction(tx.id);
    await _load();
  }

  Future<void> _markCodPaid(Transaction tx) async {
    await _api.markCodPaid(tx.id);
    await _load();
  }

  Future<void> _openEditTransaction(Transaction tx) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTransactionSheet(transaction: tx),
    );
    if (updated == true) await _load();
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
          decoration:
              const InputDecoration(prefixText: '\$  ', hintText: '輸入目前餘額'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
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
        final updated = await _api.updateCardBalance(card.id, val);
        await NotificationService().checkEasyCardBalance(updated);
        await _load();
      }
    }
  }

  Future<void> _showEditCard(AppCard card) async {
    final isEasycard = card.type == 'easycard';
    final isCredit = card.type == 'credit';
    final nameCtrl = TextEditingController(text: card.name);
    final bankCtrl = TextEditingController(text: card.bank ?? '');
    final lastFourCtrl = TextEditingController(text: card.lastFour ?? '');
    final balanceCtrl = TextEditingController(
        text: card.balance != null ? card.balance!.toStringAsFixed(0) : '');
    final dueAmountCtrl = TextEditingController(
        text: card.dueAmount != null ? card.dueAmount!.toStringAsFixed(0) : '');
    final creditLimitCtrl = TextEditingController(
        text: card.creditLimit != null ? card.creditLimit!.toStringAsFixed(0) : '');
    final dueDayCtrl = TextEditingController(text: card.paymentDueDate ?? '');
    final reminderDayCtrl =
        TextEditingController(text: card.reminderDay?.toString() ?? '');
    String selectedColor = card.color;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '編輯卡片',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '卡片名稱'),
              ),
              const SizedBox(height: 10),
              if (!isEasycard) ...[
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(labelText: '銀行 *'),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: lastFourCtrl,
                decoration: const InputDecoration(labelText: '卡號後四碼 *'),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              if (!isCredit) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: balanceCtrl,
                  decoration: const InputDecoration(
                      labelText: '目前餘額（選填）', prefixText: '\$ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              if (isCredit) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: dueAmountCtrl,
                  decoration: const InputDecoration(
                      labelText: '目前需要繳的金額（選填）', prefixText: '\$ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: creditLimitCtrl,
                  decoration: const InputDecoration(
                      labelText: '信用額度（選填，用來換算可用額度）', prefixText: '\$ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDayCtrl,
                  decoration: const InputDecoration(
                    labelText: '繳卡費日（每月幾號，例：25）',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reminderDayCtrl,
                  decoration: const InputDecoration(
                    labelText: '提醒通知日（每月幾號）',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              Text(
                '顏色',
                style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 10),
              _ColorSwatches(
                selected: selectedColor,
                onChanged: (c) => setLocal(() => selectedColor = c),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('儲存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _api.updateCard(
          card.id,
          name: nameCtrl.text.trim().isEmpty ? card.name : nameCtrl.text.trim(),
          type: card.type,
          color: selectedColor,
          bank: isEasycard
              ? null
              : (bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim()),
          lastFour: lastFourCtrl.text.trim().isEmpty
              ? null
              : lastFourCtrl.text.trim(),
          balance: isCredit ? null : double.tryParse(balanceCtrl.text),
          dueAmount: isCredit ? double.tryParse(dueAmountCtrl.text) : null,
          creditLimit: isCredit ? double.tryParse(creditLimitCtrl.text) : null,
          paymentDueDate: isCredit && dueDayCtrl.text.trim().isNotEmpty
              ? dueDayCtrl.text.trim()
              : null,
          reminderDay: isCredit ? int.tryParse(reminderDayCtrl.text) : null,
        );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('更新失敗：$e')));
        }
      }
    }
  }

  void _openAddTransaction() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddTransactionSheet(
        cards: _cards,
        outstandingLoans: outstandingLoans(_transactions),
      ),
    );
    if (added == true) await _load();
  }

  String _scopeLabel() {
    if (_scope == 'all') return '全部';
    if (_scope == 'cash') return '💵 現金';
    final id = int.tryParse(_scope.substring('card_'.length));
    final match = _cards.where((c) => c.id == id);
    return match.isEmpty ? '全部' : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTransactions;
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
                  // ── 範圍切換（全部 / 現金）──────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('🗂 全部'),
                            selected: _scope == 'all',
                            onSelected: (_) => setState(() => _scope = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('💵 現金'),
                            selected: _scope == 'cash',
                            onSelected: (_) => setState(() => _scope = 'cash'),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              '目前顯示：${_scopeLabel()}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Card carousel ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _cards.isEmpty
                        ? _EmptyCardsHint()
                        : _CardCarousel(
                            cards: _cards,
                            controller: _cardPageController,
                            currentIndex: _cardPage,
                            onPageChanged: (i) => setState(() {
                              _cardPage = i;
                              _scope = 'card_${_cards[i].id}';
                            }),
                            onUpdateBalance: _showUpdateBalance,
                            onEdit: _showEditCard,
                          ),
                  ),
                  // ── Transaction list ───────────────────────────────────
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTransactionsHint(),
                    )
                  else
                    _TransactionSliver(
                      transactions: visible,
                      onDelete: _deleteTransaction,
                      onMarkPaid: _markCodPaid,
                      onTap: _openEditTransaction,
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
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onUpdateBalance,
    required this.onEdit,
  });

  final List<AppCard> cards;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AppCard> onUpdateBalance;
  final ValueChanged<AppCard> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: controller,
            itemCount: cards.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => _CardTile(
              card: cards[i],
              onUpdateBalance: () => onUpdateBalance(cards[i]),
              onEdit: () => onEdit(cards[i]),
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
  const _CardTile({
    required this.card,
    required this.onUpdateBalance,
    required this.onEdit,
  });

  final AppCard card;
  final VoidCallback onUpdateBalance;
  final VoidCallback onEdit;

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEasycard)
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white70, size: 18),
                        tooltip: '更新餘額',
                        onPressed: onUpdateBalance,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (isEasycard) const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: Colors.white70, size: 18),
                      tooltip: '編輯卡片',
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.type == 'credit'
                  ? (card.dueAmount != null
                      ? NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                          .format(card.dueAmount)
                      : '未設定應繳金額')
                  : (card.balance != null
                      ? NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                          .format(card.balance)
                      : '未設定餘額'),
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
    required this.onMarkPaid,
    required this.onTap,
  });

  final List<Transaction> transactions;
  final ValueChanged<Transaction> onDelete;
  final ValueChanged<Transaction> onMarkPaid;
  final ValueChanged<Transaction> onTap;

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
                          TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('取消')),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('刪除'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => onDelete(tx),
                  child: GestureDetector(
                    onTap: () => onTap(tx),
                    child: _TransactionTile(
                      tx: tx,
                      onMarkPaid: tx.isCodUnpaid ? () => onMarkPaid(tx) : null,
                    ),
                  ),
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
  const _TransactionTile({required this.tx, this.onMarkPaid});
  final Transaction tx;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.isExpense;
    final unpaidCod = tx.isCodUnpaid;
    final isLoan = tx.isLoan && tx.loanPerson != null;
    const codColor = Color(0xFFF59E0B);
    final loanColor = isLoan ? personColor(tx.loanPerson!) : null;
    final amountStr =
        '${isExpense ? '-' : '+'}\$${NumberFormat('#,##0').format(tx.amount.abs())}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: unpaidCod
            ? codColor.withValues(alpha: 0.15)
            : (loanColor?.withValues(alpha: 0.15) ??
                (isExpense
                    ? Theme.of(context).colorScheme.errorContainer
                    : const Color(0xFFD1FAE5))),
        child: Icon(
          unpaidCod
              ? Icons.local_shipping_outlined
              : (isLoan
                  ? Icons.handshake_outlined
                  : (isExpense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)),
          size: 18,
          color: unpaidCod
              ? codColor
              : (loanColor ??
                  (isExpense
                      ? Theme.of(context).colorScheme.error
                      : const Color(0xFF059669))),
        ),
      ),
      title: Text(tx.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoan) ...[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration:
                  BoxDecoration(color: loanColor, shape: BoxShape.circle),
            ),
          ],
          Text(
            unpaidCod
                ? '⚠ 貨到付款未付'
                : (isLoan ? tx.loanPerson! : (tx.card?.name ?? '')),
            style: TextStyle(
              fontSize: 12,
              fontWeight: (unpaidCod || isLoan) ? FontWeight.w600 : null,
              color: unpaidCod ? codColor : loanColor,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amountStr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: unpaidCod
                  ? codColor
                  : (loanColor ??
                      (isExpense
                          ? Theme.of(context).colorScheme.error
                          : const Color(0xFF059669))),
            ),
          ),
          if (onMarkPaid != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMarkPaid,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: codColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('標記已付',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
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

// ── Color swatches for card edit ─────────────────────────────────────────────
class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _colors = [
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#EF4444',
    '#F59E0B',
    '#10B981',
    '#6B7280',
    '#0EA5E9',
    '#14B8A6',
    '#F97316',
    '#84CC16',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colors.map((hex) {
        final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
        final isSelected = selected.toUpperCase() == hex.toUpperCase();
        return GestureDetector(
          onTap: () => onChanged(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border:
                  isSelected ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.6), blurRadius: 8)
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

String _dateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return '今天';
  if (d == today.subtract(const Duration(days: 1))) return '昨天';
  return DateFormat('M/d').format(dt);
}
