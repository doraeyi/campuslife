import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../models/shift.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'add_transaction_sheet.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _api = ApiClient();
  List<Shift> _shifts = [];
  List<AppCard> _cards = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  String _selectedType = 'all';
  int _cardPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.fetchShifts(),
        _api.fetchCards(),
        _api.fetchTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _shifts = results[0] as List<Shift>;
          _cards = results[1] as List<AppCard>;
          _transactions = results[2] as List<Transaction>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppCard> get _filteredCards {
    if (_selectedType == 'all') return _cards;
    return _cards.where((c) => c.type == _selectedType).toList();
  }

  List<Transaction> get _recentTransactions {
    final now = DateTime.now();
    final List<Transaction> base;
    if (_selectedType == 'all') {
      base = _transactions;
    } else {
      final ids = _filteredCards.map((c) => c.id).toSet();
      base = _transactions.where((t) => t.cardId != null && ids.contains(t.cardId)).toList();
    }
    return base
        .where((t) => t.createdAt.year == now.year && t.createdAt.month == now.month)
        .take(6)
        .toList();
  }

  double get _monthlyExpense {
    return _recentTransactions
        .where((t) => t.amount < 0)
        .fold(0.0, (s, t) => s + t.amount.abs());
  }

  double get _monthlyIncome {
    return _recentTransactions
        .where((t) => t.amount > 0)
        .fold(0.0, (s, t) => s + t.amount);
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
      _cardPage = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _openAddTransaction() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(cards: _cards),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final now = DateTime.now();
    final filtered = _filteredCards;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    surfaceTintColor: Colors.transparent,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '嗨，${user?.displayName ?? ''}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          DateFormat('yyyy年M月').format(now),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: '快速記帳',
                        onPressed: _openAddTransaction,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Type filter chips ─────────────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _FilterChip(label: '全部', value: 'all', selected: _selectedType, onTap: _selectType),
                              const SizedBox(width: 8),
                              _FilterChip(label: '💳  信用卡', value: 'credit', selected: _selectedType, onTap: _selectType),
                              const SizedBox(width: 8),
                              _FilterChip(label: '🏧  金融卡', value: 'debit', selected: _selectedType, onTap: _selectType),
                              const SizedBox(width: 8),
                              _FilterChip(label: '🚌  悠遊卡', value: 'easycard', selected: _selectedType, onTap: _selectType),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Card PageView ─────────────────────────────────────
                        if (filtered.isEmpty)
                          _EmptyCards(onAdd: _openAddTransaction)
                        else ...[
                          SizedBox(
                            height: 190,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: filtered.length,
                              onPageChanged: (i) => setState(() => _cardPage = i),
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: _BigCard(card: filtered[i]),
                              ),
                            ),
                          ),
                          if (filtered.length > 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                filtered.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _cardPage ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: i == _cardPage
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),

                        // ── 本月支出 / 收入 ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  label: '本月支出',
                                  amount: _monthlyExpense,
                                  color: const Color(0xFFEF4444),
                                  icon: Icons.arrow_downward_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryTile(
                                  label: '本月收入',
                                  amount: _monthlyIncome,
                                  color: const Color(0xFF10B981),
                                  icon: Icons.arrow_upward_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── 下一個班次 ─────────────────────────────────────────
                        _NextShiftCard(shifts: _shifts),

                        const SizedBox(height: 20),

                        // ── 最近紀錄 ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '最近紀錄',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.outline,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_recentTransactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('這個月還沒有紀錄', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        else
                          ...(_recentTransactions.map(
                            (t) => _TransactionTile(tx: t, cards: _cards),
                          )),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Big card ──────────────────────────────────────────────────────────────────

class _BigCard extends StatelessWidget {
  const _BigCard({required this.card});
  final AppCard card;

  @override
  Widget build(BuildContext context) {
    final base = _hexColor(card.color);
    final dark = _darken(base, 0.22);
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final emoji = switch (card.type) {
      'credit' => '💳',
      'easycard' => '🚌',
      _ => '🏧',
    };
    final typeName = switch (card.type) {
      'credit' => '信用卡',
      'easycard' => '悠遊卡',
      _ => '金融卡',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: card name + type badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$emoji $typeName',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),

          if (card.bank != null) ...[
            const SizedBox(height: 4),
            Text(
              card.bank!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],

          const Spacer(),

          // Last four
          if (card.lastFour != null)
            Text(
              '•••• •••• •••• ${card.lastFour}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),

          const SizedBox(height: 8),

          // Balance
          Text(
            card.balance != null ? fmt.format(card.balance) : '未設定',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '目前餘額',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_outlined, size: 36, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text('還沒有卡片', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          TextButton(onPressed: onAdd, child: const Text('前往新增')),
        ],
      ),
    );
  }
}

// ── Summary tile ──────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 2),
                Text(
                  fmt.format(amount),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Next shift card ───────────────────────────────────────────────────────────

class _NextShiftCard extends StatelessWidget {
  const _NextShiftCard({required this.shifts});
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = shifts.where((s) => !s.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final next = upcoming.isEmpty ? null : upcoming.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: next?.job != null
                    ? _hexColor(next!.job!.color).withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.work_outline_rounded,
                size: 20,
                color: next?.job != null
                    ? _hexColor(next!.job!.color)
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下一個班次',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next == null
                        ? '目前沒有排班'
                        : '${next.date.month}/${next.date.day}  '
                            '${next.startTime.substring(0, 5)} - ${next.endTime.substring(0, 5)}'
                            '${next.job != null ? '  ·  ${next.job!.name}' : ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.cards});
  final Transaction tx;
  final List<AppCard> cards;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final isExpense = tx.amount < 0;
    final amountColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final amountStr = '${isExpense ? '-' : '+'}${fmt.format(tx.amount.abs())}';

    final matchList = tx.cardId != null ? cards.where((c) => c.id == tx.cardId).toList() : <AppCard>[];
    final card = tx.card ?? (matchList.isEmpty ? null : matchList.first);
    final cardName = card?.name ?? '現金';
    final cardEmoji = switch (card?.type) {
      'credit' => '💳',
      'easycard' => '🚌',
      'debit' => '🏧',
      _ => '💵',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 18,
                color: amountColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$cardEmoji $cardName',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              amountStr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
