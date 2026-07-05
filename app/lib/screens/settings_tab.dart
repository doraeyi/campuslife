import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/card_model.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'job_form_screen.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Job>> _jobsFuture;
  List<AppCard> _cards = [];

  @override
  void initState() {
    super.initState();
    _refreshJobs();
    _refreshCards();
  }

  void _refreshJobs() {
    setState(() {
      _jobsFuture = _apiClient.fetchJobs();
    });
  }

  Future<void> _refreshCards() async {
    try {
      final cards = await _apiClient.fetchCards();
      if (mounted) setState(() => _cards = cards);
    } catch (_) {}
  }

  Future<void> _deleteJob(int jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除工作'),
        content: const Text('確定要刪除這個工作嗎?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apiClient.deleteJob(jobId);
      _refreshJobs();
    }
  }

  Future<void> _addJob() async {
    final result = await Navigator.push<Job>(
      context,
      MaterialPageRoute(builder: (context) => const JobFormScreen()),
    );
    if (result != null) _refreshJobs();
  }

  Future<void> _editProfile() async {
    final currentUser = ref.read(authProvider).value;
    final controller = TextEditingController(text: currentUser?.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改顯示名稱'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '顯示名稱'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _apiClient.updateProfile(displayName: newName);
      ref.invalidate(authProvider);
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _showCardForm({AppCard? editing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardFormSheet(card: editing, apiClient: _apiClient),
    );
    if (result == true) _refreshCards();
  }

  Future<void> _deleteCard(AppCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除卡片'),
        content: Text('確定要刪除「${card.name}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apiClient.deleteCard(card.id);
      _refreshCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ── 使用者 ─────────────────────────────────────────────────────
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (user?.displayName ?? '?')[0].toUpperCase(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(user?.displayName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: TextButton(onPressed: _editProfile, child: const Text('修改')),
          ),
          const Divider(),

          // ── 我的卡片 ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Text('我的卡片', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showCardForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增卡片'),
                ),
              ],
            ),
          ),
          if (_cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showCardForm(),
                icon: const Icon(Icons.credit_card_outlined),
                label: const Text('新增第一張卡片'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            )
          else
            ..._cards.map((card) {
              final color = _hexColor(card.color);
              final emoji = switch (card.type) {
                'credit' => '💳',
                'easycard' => '🚌',
                _ => '🏧',
              };
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Text(emoji, style: const TextStyle(fontSize: 16)),
                ),
                title: Text(card.name),
                subtitle: Text([
                  if (card.type == 'easycard') '悠遊卡' else if (card.bank != null) card.bank!,
                  if (card.lastFour != null) '末四碼 ${card.lastFour}',
                  if (card.type != 'credit' && card.balance != null)
                    '餘額 \$${card.balance!.toStringAsFixed(0)}',
                  if (card.type == 'credit' && card.dueAmount != null)
                    '應繳 \$${card.dueAmount!.toStringAsFixed(0)}',
                  if (card.type == 'credit' && card.paymentDueDate != null)
                    '繳費日 ${card.paymentDueDate}號',
                ].join('  ·  ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showCardForm(editing: card),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCard(card),
                    ),
                  ],
                ),
              );
            }),
          const Divider(),

          // ── 我的工作 ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Text('我的工作', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addJob,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增工作'),
                ),
              ],
            ),
          ),
          FutureBuilder<List<Job>>(
            future: _jobsFuture,
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addJob,
                    icon: const Icon(Icons.add_business),
                    label: const Text('新增第一個工作'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                );
              }
              return Column(
                children: jobs.map((job) {
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: job.color, radius: 14),
                    title: Text(job.name),
                    subtitle: Text(job.payType == PayType.hourly
                        ? '時薪 \$${job.hourlyRate?.toStringAsFixed(0) ?? '-'}/小時'
                        : '月薪 \$${job.monthlySalary?.toStringAsFixed(0) ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteJob(job.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),

          // ── 登出 ───────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

// ── 新增 / 編輯卡片 Bottom Sheet ───────────────────────────────────────────────

class _CardFormSheet extends StatefulWidget {
  const _CardFormSheet({this.card, required this.apiClient});
  final AppCard? card;
  final ApiClient apiClient;

  @override
  State<_CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<_CardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _lastFourCtrl;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _dueAmountCtrl;
  late final TextEditingController _paymentDueDateCtrl;
  late final TextEditingController _reminderDayCtrl;
  String _type = 'credit';
  String _color = '#6366F1';
  bool _saving = false;

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
  void initState() {
    super.initState();
    final c = widget.card;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _bankCtrl = TextEditingController(text: c?.bank ?? '');
    _lastFourCtrl = TextEditingController(text: c?.lastFour ?? '');
    _balanceCtrl = TextEditingController(
        text: c?.balance != null ? c!.balance!.toStringAsFixed(0) : '');
    _dueAmountCtrl = TextEditingController(
        text: c?.dueAmount != null ? c!.dueAmount!.toStringAsFixed(0) : '');
    _paymentDueDateCtrl = TextEditingController(text: c?.paymentDueDate ?? '');
    _reminderDayCtrl = TextEditingController(text: c?.reminderDay?.toString() ?? '');
    _type = c?.type ?? 'credit';
    _color = c?.color ?? '#6366F1';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _lastFourCtrl.dispose();
    _balanceCtrl.dispose();
    _dueAmountCtrl.dispose();
    _paymentDueDateCtrl.dispose();
    _reminderDayCtrl.dispose();
    super.dispose();
  }

  Color get _colorValue =>
      Color(int.parse('FF${_color.replaceAll('#', '')}', radix: 16));

  bool get _isEasycard => _type == 'easycard';
  bool get _isCredit => _type == 'credit';
  bool get _showBalance => _type == 'debit' || _type == 'easycard';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final balance = _showBalance ? double.tryParse(_balanceCtrl.text) : null;
      final dueAmount = _isCredit ? double.tryParse(_dueAmountCtrl.text) : null;
      final paymentDueDate = _isCredit && _paymentDueDateCtrl.text.trim().isNotEmpty
          ? _paymentDueDateCtrl.text.trim()
          : null;
      final reminderDay = _isCredit ? int.tryParse(_reminderDayCtrl.text) : null;
      final bank = _isEasycard
          ? null
          : (_bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim());
      final lastFour = _lastFourCtrl.text.trim();
      if (widget.card == null) {
        await widget.apiClient.createCard(
          name: _nameCtrl.text.trim(),
          type: _type,
          color: _color,
          bank: bank,
          lastFour: lastFour,
          balance: balance,
          dueAmount: dueAmount,
          paymentDueDate: paymentDueDate,
          reminderDay: reminderDay,
        );
      } else {
        await widget.apiClient.updateCard(
          widget.card!.id,
          name: _nameCtrl.text.trim(),
          type: _type,
          color: _color,
          bank: bank,
          lastFour: lastFour,
          balance: balance,
          dueAmount: dueAmount,
          paymentDueDate: paymentDueDate,
          reminderDay: reminderDay,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.card != null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? '編輯卡片' : '新增卡片',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 卡片類型
              const Text('類型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final selected = _type == t.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? _colorValue.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(color: _colorValue, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            t.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected ? _colorValue : null,
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
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '卡片名稱 *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? '請輸入名稱' : null,
              ),
              const SizedBox(height: 12),

              // 銀行 + 卡號後四碼
              Row(
                children: [
                  if (!_isEasycard) ...[
                    Expanded(
                      child: TextFormField(
                        controller: _bankCtrl,
                        decoration: const InputDecoration(
                          labelText: '銀行 *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '請輸入銀行' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _lastFourCtrl,
                      decoration: const InputDecoration(
                        labelText: '卡號後四碼 *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      validator: (v) => v == null || v.trim().length != 4
                          ? '請輸入4碼'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 餘額（金融卡 / 悠遊卡）
              if (_showBalance) ...[
                TextFormField(
                  controller: _balanceCtrl,
                  decoration: const InputDecoration(
                    labelText: '目前餘額（選填）',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
              ],

              // 信用卡專屬欄位
              if (_isCredit) ...[
                TextFormField(
                  controller: _dueAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: '目前需要繳的金額（選填）',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paymentDueDateCtrl,
                        decoration: const InputDecoration(
                          labelText: '繳卡費日（幾號）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reminderDayCtrl,
                        decoration: const InputDecoration(
                          labelText: '提醒通知日（幾號）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 顏色
              const Text('顏色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((hex) {
                  final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                  final selected = _color == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: selected
                            ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _colorValue,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? '儲存' : '新增'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
