import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/bank_notify/providers/bank_notify_pending_provider.dart';
import '../models/card_model.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'edit_transaction_sheet.dart';
import 'wallet_screen.dart' show WalletFilter;

// 用來代表「現金」跟「全部」這兩個非實體卡片的虛擬頁面 key（存排序偏好用）
const _kCashType = 'cash';
const _kAllKey = 'all';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with WidgetsBindingObserver {
  final _api = ApiClient();
  List<AppCard> _cards = [];
  List<Transaction> _transactions = [];
  List<String> _pageOrder = [];
  bool _loading = true;
  int _page = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadPageOrder();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(bankNotifyPendingCountProvider);
    }
  }

  Future<void> _load() async {
    ref.invalidate(bankNotifyPendingCountProvider);
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

  Future<void> _loadPageOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('home_ring_page_order');
    if (saved != null && mounted) setState(() => _pageOrder = saved);
  }

  Future<void> _savePageOrder(List<String> order) async {
    final available = <String>{
      _kAllKey,
      _kCashType,
      ..._cards.map((c) => 'card_${c.id}'),
    };
    final pruned = order.where(available.contains).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_ring_page_order', pruned);
    setState(() {
      _pageOrder = pruned;
      _page = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  // key 是 'card_<id>' 時解析出對應卡片，其餘（'all'/'cash'）回傳 null
  AppCard? _cardForKey(String key) {
    if (!key.startsWith('card_')) return null;
    final id = int.tryParse(key.substring(5));
    if (id == null) return null;
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  // 頁面列表：「全部」「現金」+ 每張卡各自一頁，
  // 使用者長按圓圈圖可以自訂順序（存在本機，新出現的卡片會排在最後面）
  List<String> get _pageKeys {
    final available = <String>[
      _kAllKey,
      _kCashType,
      ..._cards.map((c) => 'card_${c.id}'),
    ];
    final ordered = <String>[];
    for (final key in _pageOrder) {
      if (available.contains(key) && !ordered.contains(key)) ordered.add(key);
    }
    for (final key in available) {
      if (!ordered.contains(key)) ordered.add(key);
    }
    return ordered;
  }

  List<AppCard> _cardsOf(String key) {
    if (key == _kAllKey) return _cards;
    if (key == _kCashType) return const [];
    final c = _cardForKey(key);
    return c == null ? const [] : [c];
  }

  List<Transaction> _txOf(String key) {
    final now = DateTime.now();
    final cardId = _cardForKey(key)?.id;
    return _transactions.where((t) {
      if (t.createdAt.year != now.year || t.createdAt.month != now.month) {
        return false;
      }
      if (key == _kAllKey) return true;
      if (key == _kCashType) return t.cardId == null;
      return cardId != null && t.cardId == cardId;
    }).toList();
  }

  double _expense(String key) => _txOf(key)
      .where((t) => t.amount < 0 && !t.isCodUnpaid)
      .fold(0.0, (s, t) => s + t.amount.abs());

  double _income(String key) => _txOf(key)
      .where((t) => t.amount > 0 && !t.isCodUnpaid)
      .fold(0.0, (s, t) => s + t.amount);

  double _balance(String key) =>
      _cardsOf(key).fold(0.0, (s, c) => s + (c.balance ?? 0));

  // 是否有貨到付款尚未付款的紀錄（不限本月，付清前持續提醒）
  bool _hasUnpaidCod(String key) {
    final cardId = _cardForKey(key)?.id;
    return _transactions.any((t) {
      if (!t.isCodUnpaid) return false;
      if (key == _kAllKey) return true;
      if (key == _kCashType) return t.cardId == null;
      return cardId != null && t.cardId == cardId;
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final now = DateTime.now();
    final pages = _pageKeys;
    final page = pages.isEmpty ? 0 : _page.clamp(0, pages.length - 1);
    final currentKey = pages.isEmpty ? _kAllKey : pages[page];

    final expense = _expense(currentKey);
    final income = _income(currentKey);
    final net = income - expense;
    final recentTx = _txOf(currentKey).take(5).toList();

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
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerLowest,
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      '嗨，${user?.displayName ?? ''}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    actions: const [
                      _BankNotifyBell(),
                      SizedBox(width: 8),
                    ],
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

                        // ── 圓圈 + PageView（點下去看該頁的紀錄，長按調順序）──
                        GestureDetector(
                          onTap: () {
                            final card = _cardForKey(currentKey);
                            context.push(
                              '/wallet',
                              extra: WalletFilter(
                                cardId: card?.id,
                                cashOnly: currentKey == _kCashType,
                              ),
                            );
                          },
                          onLongPress: _openReorderSheet,
                          child: SizedBox(
                            height: 220,
                            child: pages.isEmpty
                                ? _RingChart(
                                    net: 0,
                                    label: '月結餘',
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : PageView.builder(
                                    controller: _pageController,
                                    itemCount: pages.length,
                                    onPageChanged: (i) =>
                                        setState(() => _page = i),
                                    itemBuilder: (_, i) {
                                      final key = pages[i];
                                      final card = _cardForKey(key);
                                      final hasUnpaidCod = _hasUnpaidCod(key);
                                      final hasLoan =
                                          key == _kAllKey && _hasOutstandingLoan;
                                      final hasWarning =
                                          hasUnpaidCod || hasLoan;
                                      final color = hasWarning
                                          ? const Color(0xFFF59E0B)
                                          : _typeColor(key, context);
                                      final showBalance = card != null &&
                                          (card.type == 'debit' ||
                                              card.type == 'easycard');
                                      final value = showBalance
                                          ? _balance(key)
                                          : _income(key) - _expense(key);
                                      double? availableCredit;
                                      if (card != null &&
                                          card.type == 'credit' &&
                                          card.creditLimit != null) {
                                        final used =
                                            card.dueAmount ?? _expense(key);
                                        availableCredit =
                                            card.creditLimit! - used;
                                      }
                                      return _RingChart(
                                        net: value,
                                        label: showBalance ? '剩餘金額' : '月結餘',
                                        color: color,
                                        hasUnpaidCod: hasUnpaidCod,
                                        hasOutstandingLoan: hasLoan,
                                        creditLimit: card?.creditLimit,
                                        availableCredit: availableCredit,
                                      );
                                    },
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── 類型標籤 + 點點 ────────────────────────────────
                        Text(
                          _typeLabel(currentKey),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pages.length > 1)
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: List.generate(
                              pages.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                                width: i == page ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == page
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant,
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
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 3),
                                  padding: const EdgeInsets.only(right: 16),
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.delete_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (d) => AlertDialog(
                                      title: const Text('刪除紀錄'),
                                      content:
                                          Text('確定刪除「${t.description}」？餘額將還原。'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(d, false),
                                            child: const Text('取消')),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(d, true),
                                          child: const Text('刪除'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (_) => _deleteTransaction(t),
                                child: GestureDetector(
                                  onTap: () => _openEditTransaction(t),
                                  child: _TransactionTile(
                                    tx: t,
                                    cards: _cards,
                                    onMarkPaid: t.isCodUnpaid
                                        ? () => _markCodPaid(t)
                                        : null,
                                  ),
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

  String _typeLabel(String key) {
    if (key == _kCashType) return '💵 現金';
    final card = _cardForKey(key);
    if (card == null) return '🗂 全部';
    final emoji = switch (card.type) {
      'credit' => '💳',
      'debit' => '🏧',
      'easycard' => '🚌',
      _ => '💳',
    };
    return '$emoji ${card.name}';
  }

  Color _typeColor(String key, BuildContext context) {
    final card = _cardForKey(key);
    if (card != null) return _hexColor(card.color);
    return switch (key) {
      _kCashType => const Color(0xFF14B8A6),
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  // 長按圓圈圖：讓使用者拖曳調整頁面順序（存在本機，決定想先看哪張卡/現金/全部）
  Future<void> _openReorderSheet() async {
    var order = List<String>.from(_pageKeys);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('調整顯示順序',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, order),
                    child: const Text('完成'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('長按拖曳排序，決定想先看哪一頁',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(ctx).colorScheme.outline)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ReorderableListView(
                  shrinkWrap: true,
                  onReorder: (oldIndex, newIndex) {
                    setLocal(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (final key in order)
                      ListTile(
                        key: ValueKey(key),
                        title: Text(_typeLabel(key)),
                        trailing:
                            const Icon(Icons.drag_handle_rounded, size: 20),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) await _savePageOrder(result);
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
    this.creditLimit,
    this.availableCredit,
  });

  final double net;
  final String label;
  final Color color;
  final bool hasUnpaidCod;
  final bool hasOutstandingLoan;
  final double? creditLimit;
  final double? availableCredit;

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
                if (creditLimit != null && availableCredit != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '可用 ${fmt.format(availableCredit)}／額度 ${fmt.format(creditLimit)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
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
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
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
  const _TransactionTile(
      {required this.tx, required this.cards, this.onMarkPaid});
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
        : (loanColor ??
            (isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981)));

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
          border: unpaidCod
              ? Border.all(color: codColor.withValues(alpha: 0.5))
              : null,
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
                            fontWeight:
                                (unpaidCod || isLoan) ? FontWeight.w600 : null,
                            color: unpaidCod
                                ? codColor
                                : (loanColor ??
                                    Theme.of(context).colorScheme.outline)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
      ),
    );
  }
}

// ── Bank-notify bell ──────────────────────────────────────────────────────────

class _BankNotifyBell extends ConsumerWidget {
  const _BankNotifyBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(bankNotifyPendingCountProvider).value ?? 0;

    return IconButton(
      icon: count > 0
          ? Badge(
              label: Text('$count'),
              child: const Icon(Icons.notifications_outlined),
            )
          : const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/settings/bank-notify'),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
