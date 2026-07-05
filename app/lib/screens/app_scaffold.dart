import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/card_model.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import 'add_transaction_sheet.dart';

// ── Design constants ──────────────────────────────────────────────────────────
const _kActive   = Color(0xFFFBBF24);
const _kInactive = Color(0xFFBDBDBD);

// ── Destination definitions ───────────────────────────────────────────────────
typedef _Dest = ({IconData icon, String label, String path});

const _kLeftDests = <_Dest>[
  (icon: Icons.home_rounded,           label: '首頁', path: '/dashboard'),
  (icon: Icons.calendar_month_rounded, label: '班表', path: '/schedule'),
];

const _kRightDests = <_Dest>[
  (icon: Icons.group_rounded,          label: '好友', path: '/friends'),
  (icon: Icons.settings_rounded,       label: '設定', path: '/settings'),
];

// ── AppScaffold ───────────────────────────────────────────────────────────────
class AppScaffold extends HookConsumerWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingPillNav(
        location: location,
        onNavigate: context.go,
        onAdd: () => _openQuickAddTransaction(context),
      ),
    );
  }
}

// ── Floating pill nav ─────────────────────────────────────────────────────────
class _FloatingPillNav extends StatelessWidget {
  const _FloatingPillNav({
    required this.location,
    required this.onNavigate,
    required this.onAdd,
  });

  final String location;
  final void Function(String) onNavigate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      // Transparent so body content shows through the margins
      color: Colors.transparent,
      height: 64 + bottomPadding + 20,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPadding + 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ..._kLeftDests.map((d) => _PillItem(
                icon: d.icon,
                label: d.label,
                isActive: location.startsWith(d.path),
                onTap: () => onNavigate(d.path),
              )),
              _PillFab(onTap: onAdd),
              ..._kRightDests.map((d) => _PillItem(
                icon: d.icon,
                label: d.label,
                isActive: location.startsWith(d.path),
                onTap: () => onNavigate(d.path),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PillItem ──────────────────────────────────────────────────────────────────
class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kActive : _kInactive;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? _kActive.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center FAB inside pill ────────────────────────────────────────────────────
class _PillFab extends StatelessWidget {
  const _PillFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _kActive,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x50FBBF24),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

// ── Quick-add: 直接開支出/收入 + 數字鍵盤 ───────────────────────────────────────
Future<void> _openQuickAddTransaction(BuildContext context) async {
  final api = ApiClient();
  final results = await Future.wait([
    api.fetchCards().catchError((_) => <AppCard>[]),
    api.fetchTransactions().catchError((_) => <Transaction>[]),
  ]);
  if (!context.mounted) return;
  final cards = results[0] as List<AppCard>;
  final transactions = results[1] as List<Transaction>;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AddTransactionSheet(
      cards: cards,
      outstandingLoans: outstandingLoans(transactions),
    ),
  );
}
