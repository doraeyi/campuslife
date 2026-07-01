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
  (icon: Icons.receipt_long_rounded,   label: '記帳', path: '/wallet'),
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
      floatingActionButton: _AddFab(
        onTap: () => _showQuickAdd(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        location: location,
        onNavigate: context.go,
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
class _AddFab extends StatelessWidget {
  const _AddFab({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        backgroundColor: _kActive,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: onTap,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

// ── BottomBar ─────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.location, required this.onNavigate});

  final String location;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              ..._kLeftDests.map(
                (d) => _TabItem(
                  icon: d.icon,
                  label: d.label,
                  isActive: location.startsWith(d.path),
                  onTap: () => onNavigate(d.path),
                ),
              ),
              const SizedBox(width: 72),
              ..._kRightDests.map(
                (d) => _TabItem(
                  icon: d.icon,
                  label: d.label,
                  isActive: location.startsWith(d.path),
                  onTap: () => onNavigate(d.path),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TabItem ───────────────────────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  const _TabItem({
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
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

// ── Quick-add sheet ───────────────────────────────────────────────────────────
void _showQuickAdd(BuildContext context) {
  showModalBottomSheet(
    context: context,
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
                Navigator.of(context).push(
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
