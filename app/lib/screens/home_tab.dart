import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _api = ApiClient();
  List<AppCard> _cards = [];
  List<Transaction> _transactions = [];
  bool _loading = true;
  int _page = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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

  // 有哪些卡片類型（按出現順序去重）
  List<String> get _availableTypes {
    final seen = <String>{};
    final types = <String>[];
    for (final c in _cards) {
      if (seen.add(c.type)) types.add(c.type);
    }
    return types;
  }

  // 頁面列表：第 0 頁是「全部」，之後每個有卡片的類型一頁
  List<String?> get _pages => [null, ..._availableTypes];

  List<AppCard> _cardsOf(String? type) =>
      type == null ? _cards : _cards.where((c) => c.type == type).toList();

  List<Transaction> _txOf(String? type) {
    final now = DateTime.now();
    final ids = _cardsOf(type).map((c) => c.id).toSet();
    return _transactions.where((t) {
      if (t.createdAt.year != now.year || t.createdAt.month != now.month) return false;
      if (type == null) return true;
      return t.cardId != null && ids.contains(t.cardId);
    }).toList();
  }

  double _expense(String? type) => _txOf(type)
      .where((t) => t.amount < 0 && !t.isCodUnpaid)
      .fold(0.0, (s, t) => s + t.amount.abs());

  double _income(String? type) => _txOf(type)
      .where((t) => t.amount > 0 && !t.isCodUnpaid)
      .fold(0.0, (s, t) => s + t.amount);

  double _balance(String? type) =>
      _cardsOf(type).fold(0.0, (s, c) => s + (c.balance ?? 0));

  // 是否有貨到付款尚未付款的紀錄（不限本月，付清前持續提醒）
  bool _hasUnpaidCod(String? type) {
    final ids = _cardsOf(type).map((c) => c.id).toSet();
    return _transactions.any((t) {
      if (!t.isCodUnpaid) return false;
      if (type == null) return true;
      return t.cardId != null && ids.contains(t.cardId);
    });
  }

  // 是否有借出還沒還清的紀錄（借款不分卡片類型，只在「全部」分頁提醒）
  bool get _hasOutstandingLoan => outstandingLoans(_transactions).isNotEmpty;

  Future<void> _deleteTransaction(Transaction tx) async {
    await _api.deleteTransaction(tx.id);
    await _load();
  }

  Future<void> _markCodPaid(Transaction tx) async {
    await _api.markCodPaid(tx.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final now = DateTime.now();
    final pages = _pages;
    final currentType = _page < pages.length ? pages[_page] : null;

    final expense = _expense(currentType);
    final income = _income(currentType);
    final net = income - expense;
    final recentTx = _txOf(currentType).take(5).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── AppBar ────────────────────────────────────────────────
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      '嗨，${user?.displayName ?? ''}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ── 月份 ───────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chevron_left_rounded,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy年M月').format(now),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded,
                                  color: Theme.of(context).colorScheme.outline),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── 月支出 / 月收入 ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _TopStat(
                                label: '月支出',
                                amount: expense,
                                color: const Color(0xFFEF4444),
                              ),
                              _TopStat(
                                label: '月收入',
                                amount: income,
                                color: const Color(0xFF10B981),
                                alignRight: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── 圓圈 + PageView ────────────────────────────────
                        SizedBox(
                          height: 220,
                          child: pages.isEmpty
                              ? _RingChart(
                                  net: 0,
                                  label: '月結餘',
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: pages.length,
                                  onPageChanged: (i) => setState(() => _page = i),
                                  itemBuilder: (_, i) {
                                    final type = pages[i];
                                    final cards = _cardsOf(type);
                                    final hasUnpaidCod = _hasUnpaidCod(type);
                                    final hasLoan = type == null && _hasOutstandingLoan;
                                    final hasWarning = hasUnpaidCod || hasLoan;
                                    final color = hasWarning
                                        ? const Color(0xFFF59E0B)
                                        : _typeColor(type, cards, context);
                                    final showBalance =
                                        type == 'debit' || type == 'easycard';
                                    final value = showBalance
                                        ? _balance(type)
                                        : _income(type) - _expense(type);
                                    return _RingChart(
                                      net: value,
                                      label: showBalance ? '剩餘金額' : '月結餘',
                                      color: color,
                                      hasUnpaidCod: hasUnpaidCod,
                                      hasOutstandingLoan: hasLoan,
                                    );
                                  },
                                ),
                        ),

                        const SizedBox(height: 12),

                        // ── 類型標籤 + 點點 ────────────────────────────────
                        Text(
                          _typeLabel(currentType),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pages.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              pages.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _page ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == _page
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ── 最近紀錄 ──────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                '最近紀錄',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.outline,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (recentTx.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 36, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('這個月還沒有紀錄',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        else
                          ...recentTx.map((t) => Dismissible(
                                key: ValueKey(t.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  padding: const EdgeInsets.only(right: 16),
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.delete_rounded,
                                      color: Theme.of(context).colorScheme.onErrorContainer),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (d) => AlertDialog(
                                      title: const Text('刪除紀錄'),
                                      content: Text('確定刪除「${t.description}」？餘額將還原。'),
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
                                onDismissed: (_) => _deleteTransaction(t),
                                child: _TransactionTile(
                                  tx: t,
                                  cards: _cards,
                                  onMarkPaid: t.isCodUnpaid ? () => _markCodPaid(t) : null,
                                ),
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

  String _typeLabel(String? type) => switch (type) {
        'credit' => '💳 信用卡',
        'debit' => '🏧 金融卡',
        'easycard' => '🚌 悠遊卡',
        _ => '🗂 全部',
      };

  Color _typeColor(String? type, List<AppCard> cards, BuildContext context) {
    if (cards.isNotEmpty) return _hexColor(cards.first.color);
    return switch (type) {
      'credit' => const Color(0xFF6366F1),
      'debit' => const Color(0xFF0EA5E9),
      'easycard' => const Color(0xFF10B981),
      _ => Theme.of(context).colorScheme.primary,
    };
  }
}

// ── Ring chart ────────────────────────────────────────────────────────────────

class _RingChart extends StatelessWidget {
  const _RingChart({
    required this.net,
    required this.label,
    required this.color,
    this.hasUnpaidCod = false,
    this.hasOutstandingLoan = false,
  });

  final double net;
  final String label;
  final Color color;
  final bool hasUnpaidCod;
  final bool hasOutstandingLoan;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(200, 200),
              painter: _RingPainter(color: color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(net),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: net >= 0
                        ? Theme.of(context).colorScheme.onSurface
                        : const Color(0xFFEF4444),
                  ),
                ),
                if (hasUnpaidCod) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '⚠ 有貨到付款未付',
                    style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                  ),
                ],
                if (hasOutstandingLoan) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '⚠ 有借款未還',
                    style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;
    const strokeW = 14.0;

    // Track
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = color.withValues(alpha: 0.12),
    );

    // Arc (static decorative, 3/4 circle)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

// ── Top stat ──────────────────────────────────────────────────────────────────

class _TopStat extends StatelessWidget {
  const _TopStat({
    required this.label,
    required this.amount,
    required this.color,
    this.alignRight = false,
  });

  final String label;
  final double amount;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 14, color: Theme.of(context).colorScheme.outline),
          ],
        ),
        Text(
          fmt.format(amount),
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.cards, this.onMarkPaid});
  final Transaction tx;
  final List<AppCard> cards;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final isExpense = tx.amount < 0;
    final unpaidCod = tx.isCodUnpaid;
    final isLoan = tx.isLoan && tx.loanPerson != null;
    const codColor = Color(0xFFF59E0B);
    final loanColor = isLoan ? personColor(tx.loanPerson!) : null;
    final color = unpaidCod
        ? codColor
        : (loanColor ?? (isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981)));

    final matchList = tx.cardId != null
        ? cards.where((c) => c.id == tx.cardId).toList()
        : <AppCard>[];
    final card = tx.card ?? (matchList.isEmpty ? null : matchList.first);
    final cardEmoji = switch (card?.type) {
      'credit' => '💳',
      'easycard' => '🚌',
      'debit' => '🏧',
      _ => '💵',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: unpaidCod ? Border.all(color: codColor.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                unpaidCod
                    ? Icons.local_shipping_outlined
                    : (isLoan
                        ? Icons.handshake_outlined
                        : (isExpense
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded)),
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      if (isLoan) ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: loanColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        unpaidCod
                            ? '⚠ 貨到付款未付'
                            : (isLoan
                                ? tx.loanPerson!
                                : '$cardEmoji ${card?.name ?? '現金'}'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: (unpaidCod || isLoan) ? FontWeight.w600 : null,
                            color: unpaidCod
                                ? codColor
                                : (loanColor ?? Theme.of(context).colorScheme.outline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${fmt.format(tx.amount.abs())}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color),
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
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
