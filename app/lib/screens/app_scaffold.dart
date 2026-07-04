import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/card_model.dart';
import '../services/api_client.dart';
import 'add_transaction_sheet.dart';
import 'add_shift_screen.dart';

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
        onAdd: () => _showQuickAdd(context),
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

// ── Quick-add sheet ───────────────────────────────────────────────────────────
void _showQuickAdd(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  List<AppCard> _cards = [];

  @override
  void initState() {
    super.initState();
    ApiClient().fetchCards().then((cards) {
      if (mounted) setState(() => _cards = cards);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '快速新增',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEF4444),
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
              title: const Text('記錄支出'),
              subtitle: const Text('扣除卡片餘額'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => AddTransactionSheet(cards: _cards, prefillType: 'expense'),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF10B981),
                child: Icon(Icons.arrow_downward_rounded, color: Colors.white),
              ),
              title: const Text('記錄收入'),
              subtitle: const Text('增加卡片餘額'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => AddTransactionSheet(cards: _cards, prefillType: 'income'),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF3B82F6),
                child: Icon(Icons.work_outline_rounded, color: Colors.white),
              ),
              title: const Text('新增班次'),
              subtitle: const Text('記錄一筆工作排班'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const AddShiftScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
