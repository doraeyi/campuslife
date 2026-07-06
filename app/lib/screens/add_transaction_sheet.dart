import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/card_model.dart';
import '../services/api_client.dart';

// ── Categories ────────────────────────────────────────────────────────────────
typedef Cat = ({String id, String emoji, String label});

const expenseCategories = <Cat>[
  (id: 'food', emoji: '🍜', label: '餐飲'),
  (id: 'transport', emoji: '🚌', label: '交通'),
  (id: 'medical', emoji: '💊', label: '醫療'),
  (id: 'shopping', emoji: '🛍️', label: '購物'),
  (id: 'transfer', emoji: '💸', label: '轉帳'),
  (id: 'daily', emoji: '🏠', label: '日常'),
  (id: 'entertainment', emoji: '🎮', label: '娛樂'),
  (id: 'education', emoji: '📚', label: '教育'),
  (id: 'loan', emoji: '🤝', label: '借錢'),
  (id: 'other', emoji: '📦', label: '其他'),
];

const incomeCategories = <Cat>[
  (id: 'salary', emoji: '💰', label: '薪資'),
  (id: 'bonus', emoji: '🎁', label: '獎金'),
  (id: 'transfer', emoji: '💸', label: '轉帳'),
  (id: 'invest', emoji: '📈', label: '投資'),
  (id: 'loan', emoji: '🤝', label: '還錢'),
  (id: 'other', emoji: '📦', label: '其他'),
];

// ── Payment option ────────────────────────────────────────────────────────────
typedef _Pay = ({int? cardId, String emoji, String label});

List<_Pay> _buildPayOptions(List<AppCard> cards) => [
      (cardId: null, emoji: '💵', label: '現金'),
      ...cards.map((c) => (
            cardId: c.id,
            emoji: _cardEmoji(c.type),
            label:
                '${_cardShortName(c.type)} ${c.lastFour != null ? '···· ${c.lastFour}' : c.name}',
          )),
    ];

String _cardEmoji(String type) => switch (type) {
      'credit' => '💳',
      'easycard' => '🎫',
      _ => '🏦',
    };

String _cardShortName(String type) => switch (type) {
      'credit' => '信用卡',
      'easycard' => '悠遊卡',
      _ => '金融卡',
    };

// ── Sheet ─────────────────────────────────────────────────────────────────────
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({
    super.key,
    required this.cards,
    this.prefillAmount,
    this.prefillType,
    this.outstandingLoans = const {},
  });

  final List<AppCard> cards;
  final double? prefillAmount;
  final String? prefillType;
  final Map<String, double> outstandingLoans;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _api = ApiClient();
  final _noteCtrl = TextEditingController();
  final _loanPersonCtrl = TextEditingController();

  String _type = 'expense';
  String _amountStr = '0';
  String? _category;
  int? _selectedCardId; // null = 現金
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _isCod = false;
  String? _repayPerson;

  bool get _isLoan => _category == 'loan';

  List<_Pay> get _payOptions => _buildPayOptions(widget.cards);
  List<Cat> get _categories =>
      _type == 'expense' ? expenseCategories : incomeCategories;

  @override
  void initState() {
    super.initState();
    _type = widget.prefillType ?? 'expense';
    if (widget.prefillAmount != null) {
      _amountStr = widget.prefillAmount!.toStringAsFixed(0);
    }
    // Default payment: first card if exists, else cash
    if (widget.cards.isNotEmpty) {
      _selectedCardId = widget.cards.first.id;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _loanPersonCtrl.dispose();
    super.dispose();
  }

  // ── Numpad logic ─────────────────────────────────────────────────────────
  void _onNumpad(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amountStr.length <= 1) {
          _amountStr = '0';
        } else {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        }
      } else if (key == '.') {
        if (!_amountStr.contains('.')) _amountStr += '.';
      } else if (key == '00') {
        if (_amountStr != '0') _amountStr += '00';
      } else {
        if (_amountStr == '0') {
          _amountStr = key;
        } else {
          // Max 2 decimal places
          final dotIdx = _amountStr.indexOf('.');
          if (dotIdx != -1 && _amountStr.length - dotIdx > 2) return;
          _amountStr += key;
        }
      }
    });
  }

  double get _amount => double.tryParse(_amountStr) ?? 0;

  String? get _loanPerson =>
      _type == 'expense' ? _loanPersonCtrl.text.trim() : _repayPerson;

  Future<void> _submit() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('請輸入金額'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_isLoan && (_loanPerson == null || _loanPerson!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_type == 'expense' ? '請填寫借給誰' : '請選擇還款的人'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final signedAmount = _type == 'expense' ? -_amount : _amount;
      final note = _noteCtrl.text.trim();
      await _api.createTransaction(
        cardId: _selectedCardId,
        amount: signedAmount,
        description: _isLoan
            ? (_type == 'expense' ? '借錢給 $_loanPerson' : '$_loanPerson 還錢')
            : (_category != null
                ? _categories.firstWhere((c) => c.id == _category).label
                : (_type == 'expense' ? '支出' : '收入')),
        transactionType: _type,
        category: _category,
        note: note.isEmpty ? null : note,
        isCod: _isCod,
        isLoan: _isLoan,
        loanPerson: _isLoan ? _loanPerson : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('記帳失敗，請再試一次'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';
    final accentColor =
        isExpense ? const Color(0xFFFF4D6D) : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Text(
                    '新增紀錄',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // ── Type toggle ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _TypeToggle(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                _category = null;
                if (v != 'expense') _isCod = false;
                _loanPersonCtrl.clear();
                _repayPerson = null;
              }),
            ),
          ),

          // ── Category grid ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: CategoryGrid(
              categories: _categories,
              selected: _category,
              onTap: (id) => setState(() {
                _category = _category == id ? null : id;
                if (_category != 'loan') {
                  _loanPersonCtrl.clear();
                  _repayPerson = null;
                }
              }),
            ),
          ),

          // ── 沒有欠款可還時的提示 ───────────────────────────────────────
          if (_isLoan && !isExpense && widget.outstandingLoans.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '目前沒有人欠你錢',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),

          // ── Amount display ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '\$$_amountStr',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),

          // ── Date + note row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                // Date chip
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(_date),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.calendar_today_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 借給誰 / 誰還錢（借錢分類啟用時顯示）
                if (_isLoan && isExpense) ...[
                  Expanded(
                    child: TextField(
                      controller: _loanPersonCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '借給誰',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (_isLoan &&
                    !isExpense &&
                    widget.outstandingLoans.isNotEmpty) ...[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _repayPerson,
                      isDense: true,
                      isExpanded: true,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '誰還錢',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: widget.outstandingLoans.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  '${e.key}（欠 \$${e.value.toStringAsFixed(0)}）',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _repayPerson = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Note field
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '新增備註',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Payment chips ─────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _payOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final opt = _payOptions[i];
                final selected = _selectedCardId == opt.cardId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCardId = opt.cardId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1E3A5F)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(opt.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 貨到付款 ──────────────────────────────────────────────────
          if (isExpense)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _isCod,
                      onChanged: (v) => setState(() => _isCod = v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isCod = !_isCod),
                    child: const Text(
                      '貨到付款（尚未付款，付款前不計入餘額）',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // ── Numpad ────────────────────────────────────────────────────
          _Numpad(
            onKey: _onNumpad,
            onSave: _saving ? null : _submit,
            accentColor: accentColor,
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Type toggle ───────────────────────────────────────────────────────────────
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _Pill(
            label: '支出',
            selected: value == 'expense',
            selectedColor: const Color(0xFFFF4D6D),
            onTap: () => onChanged('expense'),
          ),
          _Pill(
            label: '收入',
            selected: value == 'income',
            selectedColor: const Color(0xFF10B981),
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category grid ─────────────────────────────────────────────────────────────
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.onTap,
  });
  final List<Cat> categories;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 4,
      childAspectRatio: 0.85,
      children: categories.map((c) {
        final isSelected = selected == c.id;
        return GestureDetector(
          onTap: () => onTap(c.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(c.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 4),
              Text(
                c.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────
class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onKey,
    required this.onSave,
    required this.accentColor,
  });
  final ValueChanged<String> onKey;
  final VoidCallback? onSave;
  final Color accentColor;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    '00',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          // Number grid (3×4)
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: _keys
                  .map((k) => _NumKey(label: k, onTap: () => onKey(k)))
                  .toList(),
            ),
          ),
          // Right column: backspace + save
          SizedBox(
            width: 76,
            child: Column(
              children: [
                _NumKey(
                  label: '⌫',
                  onTap: () => onKey('⌫'),
                  flex: 1,
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onSave,
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: onSave != null
                          ? const Color(0xFFFBBF24)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '儲存',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({required this.label, required this.onTap, this.flex = 1});
  final String label;
  final VoidCallback onTap;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
