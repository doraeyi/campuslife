import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/card_model.dart';
import '../../models/group_shift.dart';
import '../../models/job.dart';
import '../../models/settings_models.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import 'providers/settings_provider.dart';
import 'widgets/job_form_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kAmber = Color(0xFFFBBF24);
const _kRose = Color(0xFFF43F5E);
const _kGreen = Color(0xFF10B981);
const _kGrey = Color(0xFF6B7280);
const _kBg = Color(0xFFF3F4F6);

// ─────────────────────────────────────────────────────────────────────────────
// SettingsPage
// ─────────────────────────────────────────────────────────────────────────────

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    final googleExpanded = useState(false);
    final lineExpanded = useState(false);
    final cardExpanded = useState(false);
    final budgetExpanded = useState(false);
    final jobExpanded = useState(false);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 個人資料卡片 ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProfileCard(profile: profileAsync.value),
              ),
              const SizedBox(height: 24),

              // ── 帳號 ──────────────────────────────────────────────────
              _SectionTitle('帳號'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      _GoogleAccordion(
                        expanded: googleExpanded.value,
                        onToggle: () => googleExpanded.value = !googleExpanded.value,
                      ),
                      const _Divider(),
                      _LineAccordion(
                        expanded: lineExpanded.value,
                        onToggle: () => lineExpanded.value = !lineExpanded.value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 好友 ──────────────────────────────────────────────────
              _SectionTitle('社群'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    leading: const Icon(Icons.group_rounded, color: Color(0xFF8B5CF6)),
                    title: const Text('好友管理'),
                    subtitle: const Text('新增好友・共享班表群組'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => context.push('/friends'),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 功能 ──────────────────────────────────────────────────
              _SectionTitle('功能'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      _CardsAccordion(
                        expanded: cardExpanded.value,
                        onToggle: () => cardExpanded.value = !cardExpanded.value,
                      ),
                      const _Divider(),
                      _BudgetAccordion(
                        expanded: budgetExpanded.value,
                        onToggle: () => budgetExpanded.value = !budgetExpanded.value,
                      ),
                      const _Divider(),
                      _JobsAccordion(
                        expanded: jobExpanded.value,
                        onToggle: () => jobExpanded.value = !jobExpanded.value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 關於 ──────────────────────────────────────────────────
              _SectionTitle('關於'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _AboutCard(),
              ),
              const SizedBox(height: 24),

              // ── 登出 ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LogoutButton(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFBBF24), Color(0xFFFCD34D)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: 0,
                  right: 0,
                  child: Center(child: _AvatarWidget(profile: profile, size: 80)),
                ),
              ],
            ),
            const SizedBox(height: 52),
            Text(
              profile?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            if (profile?.email != null)
              Text(
                profile!.email!,
                style: const TextStyle(color: _kGrey, fontSize: 13),
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              title: const Text('編輯個人資料'),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
              dense: true,
              onTap: () => context.push('/settings/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.profile, required this.size});
  final UserProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pic = profile?.picture;
    final letter = ((profile?.name?.isNotEmpty == true) ? profile!.name![0] : '?').toUpperCase();

    Widget img;
    if (pic != null && pic.startsWith('data:')) {
      img = Image.memory(base64Decode(pic.split(',').last),
          fit: BoxFit.cover, width: size, height: size);
    } else if (pic != null) {
      img = Image.network(pic, fit: BoxFit.cover, width: size, height: size,
          errorBuilder: (_, __, ___) => _letterWidget(letter));
    } else {
      img = _letterWidget(letter);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: ClipOval(child: img),
    );
  }

  Widget _letterWidget(String letter) => Container(
        color: _kAmber,
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.bold),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, color: _kGrey, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 16, endIndent: 16);
}

Widget _accordionHeader({
  required Widget leading,
  required String title,
  required Widget trailing,
  required bool expanded,
  required VoidCallback onToggle,
  BorderRadius? borderRadius,
}) {
  return InkWell(
    onTap: onToggle,
    borderRadius: borderRadius,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          trailing,
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9CA3AF), size: 20),
          ),
        ],
      ),
    ),
  );
}

Widget _badge(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Google Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleAccordion extends ConsumerWidget {
  const _GoogleAccordion({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(googleLinkProvider).value?.linked ?? false;

    return Column(
      children: [
        _accordionHeader(
          leading: _GoogleIcon(),
          title: 'Google 帳號',
          trailing: linked
              ? _badge('已綁定', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8))
              : _badge('未綁定', const Color(0xFFF3F4F6), _kGrey),
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: linked
                ? _roseOutlineBtn(
                    label: '解除 Google 綁定',
                    onTap: () => _confirmUnlink(context, '解除 Google 綁定',
                        () => ref.read(googleLinkProvider.notifier).unlink()),
                  )
                : OutlinedButton(
                    onPressed: () async {
                      final uri =
                          Uri.parse('${ApiClient.baseUrl}/api/auth/google/link-redirect');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44)),
                    child: const Text('綁定 Google 帳號'),
                  ),
          ),
      ],
    );
  }
}

Widget _roseOutlineBtn({required String label, required VoidCallback onTap}) =>
    OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _kRose),
        foregroundColor: _kRose,
        minimumSize: const Size(double.infinity, 44),
      ),
      child: Text(label),
    );

Future<void> _confirmUnlink(
  BuildContext context,
  String title,
  Future<void> Function() action,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('確定要解除綁定嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('解除', style: TextStyle(color: _kRose)),
        ),
      ],
    ),
  );
  if (ok == true) await action();
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: const Text('G',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LINE Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _LineAccordion extends HookConsumerWidget {
  const _LineAccordion({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(lineLinkProvider).value?.linked ?? false;

    final lineCode = useState<String?>(null);
    final lineCodeSecs = useState(0);
    final copied = useState(false);
    final generating = useState(false);

    // Countdown timer
    useEffect(() {
      if (lineCode.value == null) return null;
      lineCodeSecs.value = 300;
      final t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (lineCodeSecs.value <= 1) {
          lineCode.value = null;
          lineCodeSecs.value = 0;
        } else {
          lineCodeSecs.value = lineCodeSecs.value - 1;
        }
      });
      return t.cancel;
    }, [lineCode.value]);

    // Poll for completed link
    useEffect(() {
      if (lineCode.value == null) return null;
      final t = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final status = await ApiClient().fetchLineLink();
          if (status.linked) {
            lineCode.value = null;
            ref.invalidate(lineLinkProvider);
          }
        } catch (_) {}
      });
      return t.cancel;
    }, [lineCode.value]);

    final mm = (lineCodeSecs.value ~/ 60).toString().padLeft(2, '0');
    final ss = (lineCodeSecs.value % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accordionHeader(
          leading: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          title: 'LINE Bot 自動記帳',
          trailing: linked
              ? _badge('已綁定', const Color(0xFFD1FAE5), const Color(0xFF065F46))
              : _badge('未綁定', const Color(0xFFF3F4F6), _kGrey),
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: linked
                ? Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LINE 帳號已綁定。直接傳給 Bot 訊息即可自動記帳。',
                          style: TextStyle(color: Color(0xFF065F46), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _roseOutlineBtn(
                        label: '解除 LINE 綁定',
                        onTap: () => _confirmUnlink(context, '解除 LINE 綁定',
                            () => ref.read(lineLinkProvider.notifier).unlink()),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '步驟：1. 產生綁定碼  2. 複製指令  3. 傳給 LINE Bot',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (lineCode.value == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: generating.value
                                ? null
                                : () async {
                                    generating.value = true;
                                    try {
                                      final code =
                                          await ApiClient().createLineLinkCode();
                                      lineCode.value = code;
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$e')));
                                      }
                                    } finally {
                                      generating.value = false;
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: generating.value
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('產生綁定碼'),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _kGreen, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lineCode.value!,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                              Text(
                                '$mm:$ss',
                                style: const TextStyle(
                                    fontSize: 16, color: _kGrey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(
                                  text: '/link ${lineCode.value}'));
                              copied.value = true;
                              Future.delayed(const Duration(seconds: 2),
                                  () => copied.value = false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            icon: Icon(
                                copied.value
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                size: 18),
                            label: Text(copied.value
                                ? '已複製！'
                                : '複製指令（/link ${lineCode.value}）'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cards Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _CardsAccordion extends ConsumerWidget {
  const _CardsAccordion({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final cards = cardsAsync.value ?? [];

    Widget trailing;
    if (cardsAsync.isLoading) {
      trailing = const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      trailing = Text(
        cards.isEmpty ? '尚未新增' : '${cards.length} 張',
        style: const TextStyle(color: _kGrey, fontSize: 13),
      );
    }

    return Column(
      children: [
        _accordionHeader(
          leading: const Icon(Icons.credit_card_rounded, color: Color(0xFF6366F1), size: 24),
          title: '卡片管理',
          trailing: trailing,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('卡片列表', style: TextStyle(color: _kGrey, fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showCardFormSheet(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新增'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                if (cards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('尚無卡片，點「新增」開始建立',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        children: cards.map((card) => _CardRow(card: card)).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.card});
  final AppCard card;

  Color get _color {
    final v = card.color.replaceFirst('#', '');
    return Color(int.parse('FF$v', radix: 16));
  }

  String get _subtitle {
    if (card.balance != null) return '餘額 \$${card.balance!.toStringAsFixed(0)}';
    if (card.passExpiryDate != null) return '到期 ${card.passExpiryDate}';
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: _color,
        radius: 16,
        child: const Icon(Icons.credit_card, color: Colors.white, size: 16),
      ),
      title: Text(card.name, style: const TextStyle(fontSize: 14)),
      subtitle: _subtitle.isNotEmpty ? Text(_subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TODO: edit card sheet
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: _kGrey),
            onPressed: () => showCardFormSheet(context, card: card),
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
                  title: const Text('刪除卡片'),
                  content: Text('確定要刪除「${card.name}」嗎？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('刪除', style: TextStyle(color: _kRose)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(cardsProvider.notifier).deleteCard(card.id);
              }
            },
            tooltip: '刪除',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetAccordion extends HookConsumerWidget {
  const _BudgetAccordion({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetProvider);
    final budget = budgetAsync.value;

    final ctrl = useTextEditingController();
    final saved = useState(false);
    final saving = useState(false);

    // Init controller once
    useEffect(() {
      if (budget != null && ctrl.text.isEmpty) {
        ctrl.text = budget.toStringAsFixed(0);
      }
      return null;
    }, [budget]);

    String trailing;
    if (budgetAsync.isLoading) {
      trailing = '...';
    } else if (budget != null) {
      trailing = '\$${budget.toStringAsFixed(0)}';
    } else {
      trailing = '未設定';
    }

    return Column(
      children: [
        _accordionHeader(
          leading: const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFFF59E0B), size: 24),
          title: '預算管理',
          trailing: Text(trailing, style: const TextStyle(color: _kGrey, fontSize: 13)),
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('每月預算', style: TextStyle(fontSize: 13, color: _kGrey)),
                if (budget != null)
                  Text('\$${budget.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: '輸入金額',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving.value
                          ? null
                          : () async {
                              final v = double.tryParse(ctrl.text.trim());
                              if (v == null) return;
                              saving.value = true;
                              await ref.read(budgetProvider.notifier).save(v);
                              saving.value = false;
                              saved.value = true;
                              Future.delayed(const Duration(seconds: 2),
                                  () => saved.value = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(saved.value ? '✓ 已儲存' : '儲存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Jobs Accordion
// ─────────────────────────────────────────────────────────────────────────────

class _JobsAccordion extends ConsumerWidget {
  const _JobsAccordion({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(settingsJobsProvider);
    final jobs = jobsAsync.value ?? [];

    Widget trailing;
    if (jobsAsync.isLoading) {
      trailing = const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      trailing = Text(
        jobs.isEmpty ? '未設定' : '${jobs.length} 個',
        style: const TextStyle(color: _kGrey, fontSize: 13),
      );
    }

    return Column(
      children: [
        _accordionHeader(
          leading: const Icon(Icons.work_outline_rounded,
              color: Color(0xFF8B5CF6), size: 24),
          title: '工作管理',
          trailing: trailing,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('工作列表',
                        style: TextStyle(color: _kGrey, fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showJobFormSheet(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新增'),
                      style: TextButton.styleFrom(
                        foregroundColor: _kAmber,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                if (jobs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('尚無工作，點「新增」開始建立',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  )
                else
                  ...jobs.map((job) => _JobRow(job: job)),
              ],
            ),
          ),
      ],
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final Job job;

  String get _salaryLabel {
    if (job.payType == PayType.hourly) {
      return '時薪 \$${job.hourlyRate?.toStringAsFixed(0) ?? '-'}';
    }
    return '月薪 \$${job.monthlySalary?.toStringAsFixed(0) ?? '-'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(backgroundColor: job.color, radius: 10),
      title: Text(job.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(_salaryLabel, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.group_outlined, size: 18, color: Color(0xFF6366F1)),
            onPressed: () => _showJobShareSheet(context, job),
            tooltip: '共享設定',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: _kGrey),
            onPressed: () => showJobFormSheet(context, job: job),
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
                  title: const Text('刪除工作'),
                  content: Text('確定要刪除「${job.name}」嗎？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('刪除', style: TextStyle(color: _kRose)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(settingsJobsProvider.notifier).deleteJob(job.id);
              }
            },
            tooltip: '刪除',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job Share Sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showJobShareSheet(BuildContext context, Job job) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _JobShareSheet(job: job),
    ),
  );
}

class _JobShareSheet extends HookConsumerWidget {
  const _JobShareSheet({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = useState(true);
    final friends = useState<List<_FriendShareState>>([]);

    useEffect(() {
      () async {
        try {
          final api = ApiClient();
          final allFriends = await api.fetchFriendships();
          final shares = await api.fetchJobShares(job.id);
          final sharedIds = shares.map((s) => s.sharedWith.id).toSet();
          friends.value = allFriends
              .where((f) => f.status == 'accepted')
              .map((f) => _FriendShareState(friend: f.friend, shared: sharedIds.contains(f.friend.id)))
              .toList();
        } finally {
          loading.value = false;
        }
      }();
      return null;
    }, []);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(backgroundColor: job.color, radius: 10),
              const SizedBox(width: 8),
              Text('${job.name} 共享設定',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('選擇哪些好友可以看到你這份工作的班表',
              style: TextStyle(fontSize: 13, color: _kGrey)),
          const SizedBox(height: 16),
          if (loading.value)
            const Center(child: CircularProgressIndicator())
          else if (friends.value.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('還沒有已接受的好友', style: TextStyle(color: _kGrey)),
            )
          else
            ...friends.value.map((fs) => _FriendShareTile(
              friendState: fs,
              onToggle: (val) async {
                final api = ApiClient();
                try {
                  if (val) {
                    await api.addJobShare(job.id, fs.friend.id);
                  } else {
                    await api.removeJobShare(job.id, fs.friend.id);
                  }
                  friends.value = friends.value
                      .map((f) => f.friend.id == fs.friend.id
                          ? _FriendShareState(friend: f.friend, shared: val)
                          : f)
                      .toList();
                } catch (_) {}
              },
            )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FriendShareState {
  final AppUser friend;
  final bool shared;
  _FriendShareState({required this.friend, required this.shared});
}

class _FriendShareTile extends HookWidget {
  const _FriendShareTile({required this.friendState, required this.onToggle});
  final _FriendShareState friendState;
  final Future<void> Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final toggling = useState(false);
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        child: Text(
          friendState.friend.displayName.isNotEmpty
              ? friendState.friend.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(friendState.friend.displayName, style: const TextStyle(fontSize: 14)),
      subtitle: Text(friendState.friend.email, style: const TextStyle(fontSize: 12, color: _kGrey)),
      value: friendState.shared,
      activeColor: const Color(0xFF6366F1),
      onChanged: toggling.value
          ? null
          : (val) async {
              toggling.value = true;
              await onToggle(val);
              toggling.value = false;
            },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About Card
// ─────────────────────────────────────────────────────────────────────────────

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider);
    final version = info.value?.version ?? '...';

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          title: const Text('易記帳'),
          trailing: Text(version, style: const TextStyle(color: _kGrey)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Form Sheet
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showCardFormSheet(BuildContext context, {AppCard? card}) async {
  final container = ProviderScope.containerOf(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _CardFormSheet(card: card),
    ),
  );
}

class _CardFormSheet extends HookConsumerWidget {
  const _CardFormSheet({this.card});
  final AppCard? card;

  static const _types = [
    ('credit', '💳 信用卡'),
    ('debit', '🏧 金融卡'),
    ('easycard', '🚌 悠遊卡'),
  ];

  static const _colors = [
    '#6366F1', '#8B5CF6', '#EC4899',
    '#EF4444', '#F97316', '#EAB308',
    '#10B981', '#14B8A6', '#0EA5E9',
    '#3B82F6', '#6B7280', '#1F2937',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController(text: card?.name ?? '');
    final bankCtrl = useTextEditingController(text: card?.bank ?? '');
    final lastFourCtrl = useTextEditingController(text: card?.lastFour ?? '');
    final balanceCtrl = useTextEditingController(
        text: card?.balance != null ? card!.balance!.toStringAsFixed(0) : '');
    final type = useState(card?.type ?? 'credit');
    final color = useState(card?.color ?? '#6366F1');
    final saving = useState(false);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    final colorValue = Color(int.parse('FF${color.value.replaceAll('#', '')}', radix: 16));

    Future<void> save() async {
      if (!(formKey.currentState?.validate() ?? false)) return;
      saving.value = true;
      try {
        final balance = double.tryParse(balanceCtrl.text);
        final bank = bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim();
        final lastFour = lastFourCtrl.text.trim().isEmpty ? null : lastFourCtrl.text.trim();
        if (card == null) {
          await ref.read(cardsProvider.notifier).addCard(
            name: nameCtrl.text.trim(), type: type.value, color: color.value,
            bank: bank, lastFour: lastFour, balance: balance,
          );
        } else {
          await ref.read(cardsProvider.notifier).updateCard(
            card!.id, name: nameCtrl.text.trim(), type: type.value, color: color.value,
            bank: bank, lastFour: lastFour, balance: balance,
          );
        }
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        saving.value = false;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(card == null ? '新增卡片' : '編輯卡片',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 類型
              const Text('類型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final sel = type.value == t.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => type.value = t.$1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? colorValue.withValues(alpha: 0.15) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            border: sel ? Border.all(color: colorValue, width: 1.5) : null,
                          ),
                          child: Text(t.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              color: sel ? colorValue : _kGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 名稱
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '卡片名稱 *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? '請輸入名稱' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(
                        labelText: '銀行（選填）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: lastFourCtrl,
                      decoration: const InputDecoration(
                        labelText: '末四碼',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: balanceCtrl,
                decoration: const InputDecoration(
                  labelText: '目前餘額（選填）',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // 顏色
              const Text('顏色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((hex) {
                  final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                  final sel = color.value == hex;
                  return GestureDetector(
                    onTap: () => color.value = hex,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : null,
                      ),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: saving.value ? null : save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: colorValue,
                ),
                child: saving.value
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(card == null ? '新增' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout Button
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '登出',
                style: TextStyle(
                  color: _kRose,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
