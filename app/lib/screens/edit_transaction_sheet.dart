import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/api_client.dart';
import 'add_transaction_sheet.dart'
    show Cat, CategoryGrid, expenseCategories, incomeCategories;

/// Edits amount / category / note on an existing transaction. Deliberately
/// doesn't touch card assignment, type (expense vs income), or the
/// COD/loan-specific fields — those have their own dedicated flows already,
/// and folding them in here would mean re-deriving all of AddTransactionSheet's
/// balance/loan bookkeeping for an edit path that's mainly about fixing a
/// typo or adding a note after the fact.
class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({super.key, required this.transaction});
  final Transaction transaction;

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late final _amountCtrl = TextEditingController(
    text: widget.transaction.amount.abs().toStringAsFixed(0),
  );
  late final _noteCtrl =
      TextEditingController(text: widget.transaction.note ?? '');
  late String? _category = widget.transaction.category;
  bool _saving = false;

  List<Cat> get _categories =>
      widget.transaction.isExpense ? expenseCategories : incomeCategories;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('請輸入金額'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final note = _noteCtrl.text.trim();
      final description = _category != null
          ? _categories.firstWhere((c) => c.id == _category).label
          : widget.transaction.description;
      await ApiClient().updateTransaction(
        widget.transaction.id,
        amount: amount,
        description: description,
        category: _category,
        note: note.isEmpty ? '' : note,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('更新失敗：$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.transaction.isExpense;
    final accentColor =
        isExpense ? const Color(0xFFFF4D6D) : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Expanded(
                child: Text('編輯紀錄',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 16),
          CategoryGrid(
            categories: _categories,
            selected: _category,
            onTap: (id) =>
                setState(() => _category = _category == id ? null : id),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: accentColor),
            decoration:
                const InputDecoration(labelText: '金額', prefixText: '\$ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration:
                const InputDecoration(labelText: '備註', hintText: '新增備註'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('儲存',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
