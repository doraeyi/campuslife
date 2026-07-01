import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../models/shift.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.fetchShifts(),
        _api.fetchCards(),
      ]);
      if (mounted) {
        setState(() {
          _shifts = results[0] as List<Shift>;
          _cards = results[1] as List<AppCard>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = (_shifts.where((s) => !s.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date)));
    final nextShift = upcoming.isEmpty ? null : upcoming.first;
    final thisMonthShifts = _shifts
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('首頁')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Text(
                    '你好，${user?.displayName ?? ''}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  // ── Card balance row ──────────────────────────────────
                  if (_cards.isNotEmpty) ...[
                    _SectionLabel(label: '帳戶餘額'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _MiniCardChip(card: _cards[i]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Quick expense button ──────────────────────────────
                  FilledButton.tonalIcon(
                    onPressed: _openAddTransaction,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('快速記帳'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Next shift ────────────────────────────────────────
                  _SectionLabel(label: '下一個班次'),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: nextShift?.job?.color ??
                                Theme.of(context).colorScheme.primaryContainer,
                            child: const Icon(Icons.work_outline_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextShift == null
                                      ? '目前沒有排班'
                                      : '${nextShift.date.month}/${nextShift.date.day}  '
                                          '${nextShift.startTime.substring(0, 5)}'
                                          ' - ${nextShift.endTime.substring(0, 5)}'
                                          '${nextShift.job != null ? '  ·  ${nextShift.job!.name}' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stats ─────────────────────────────────────────────
                  _SectionLabel(label: '本月概覽'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: '班次',
                          value: '${thisMonthShifts.length}',
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: '即將到來',
                          value: '${upcoming.length}',
                          icon: Icons.schedule_rounded,
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

// ── Mini card chip ────────────────────────────────────────────────────────────
class _MiniCardChip extends StatelessWidget {
  const _MiniCardChip({required this.card});
  final AppCard card;

  @override
  Widget build(BuildContext context) {
    final base = _parseColor(card.color);
    final balanceStr = card.balance != null
        ? NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(card.balance)
        : '--';

    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base, _darken(base, 0.18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            balanceStr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.3,
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
