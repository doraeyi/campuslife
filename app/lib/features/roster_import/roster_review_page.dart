import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../settings/providers/settings_provider.dart';
import 'parsers/roster_table_parser.dart';
import 'providers/roster_pending_provider.dart';

/// 排班表 OCR 猜測的校正畫面：一律要經過這裡人工確認才會寫入資料庫，
/// 不管是 LINE 傳來的照片（[pendingId] 有值）還是從相簿手動選的照片（null）。
class RosterReviewPage extends ConsumerStatefulWidget {
  const RosterReviewPage({
    super.key,
    this.pendingId,
    required this.guess,
    this.rawText,
  });

  final int? pendingId;
  final RosterTableGuess guess;
  final String? rawText;

  @override
  ConsumerState<RosterReviewPage> createState() => _RosterReviewPageState();
}

class _EditableRow {
  final TextEditingController nameCtrl;
  final List<TextEditingController> cellCtrls;

  _EditableRow(this.nameCtrl, this.cellCtrls);

  factory _EditableRow.fromGuess(RosterRowGuess g, int colCount) => _EditableRow(
        TextEditingController(text: g.employeeName),
        List.generate(
          colCount,
          (i) => TextEditingController(text: i < g.cells.length ? (g.cells[i] ?? '') : ''),
        ),
      );

  factory _EditableRow.empty(int colCount) =>
      _EditableRow(TextEditingController(), List.generate(colCount, (_) => TextEditingController()));

  void addCell() => cellCtrls.add(TextEditingController());

  void removeCell(int index) => cellCtrls.removeAt(index).dispose();

  void dispose() {
    nameCtrl.dispose();
    for (final c in cellCtrls) {
      c.dispose();
    }
  }
}

class _RosterReviewPageState extends ConsumerState<RosterReviewPage> {
  int? _selectedJobId;
  late List<DateTime> _dates;
  late List<_EditableRow> _rows;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _dates = widget.guess.dates.isNotEmpty ? List.of(widget.guess.dates) : [DateTime.now()];
    _rows = widget.guess.rows.map((r) => _EditableRow.fromGuess(r, _dates.length)).toList();
    if (_rows.isEmpty) _rows.add(_EditableRow.empty(_dates.length));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_EditableRow.empty(_dates.length)));

  void _removeRow(int index) => setState(() {
        _rows[index].dispose();
        _rows.removeAt(index);
      });

  void _addColumn() => setState(() {
        _dates.add(_dates.isNotEmpty ? _dates.last.add(const Duration(days: 1)) : DateTime.now());
        for (final r in _rows) {
          r.addCell();
        }
      });

  void _removeColumn(int index) => setState(() {
        _dates.removeAt(index);
        for (final r in _rows) {
          r.removeCell(index);
        }
      });

  Future<void> _pickDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dates[index],
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dates[index] = picked);
  }

  /// 一格文字（例如 "0700-1500"、"-"、空白）轉成給後端的 (start, end)，
  /// 無法辨識的內容一律當休假（null, null），不擋使用者送出。
  ({String? start, String? end}) _parseCell(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || RegExp(r'^[-–—]+$').hasMatch(trimmed)) {
      return (start: null, end: null);
    }
    final parts = trimmed.split(RegExp(r'[-–~]'));
    if (parts.length != 2) return (start: null, end: null);
    return (start: _normalizeTime(parts[0]), end: _normalizeTime(parts[1]));
  }

  String? _normalizeTime(String token) {
    final digits = token.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    final padded = digits.padLeft(4, '0');
    if (padded.length != 4) return null;
    return '${padded.substring(0, 2)}:${padded.substring(2)}';
  }

  Future<void> _confirm() async {
    final shifts = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final name = row.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      for (var i = 0; i < _dates.length; i++) {
        final parsed = _parseCell(row.cellCtrls[i].text);
        shifts.add({
          'employee_name': name,
          'date': _dates[i].toIso8601String().split('T').first,
          'start_time': parsed.start,
          'end_time': parsed.end,
          'note': null,
        });
      }
    }

    if (shifts.isEmpty) {
      setState(() => _message = '至少要有一位員工的姓名才能匯入');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final sortedDates = List.of(_dates)..sort();
      await ApiClient().confirmRosterImport(
        pendingId: widget.pendingId,
        jobId: _selectedJobId,
        periodStart: sortedDates.first,
        periodEnd: sortedDates.last,
        shifts: shifts,
      );
      ref.invalidate(rosterPendingCountProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('班表已匯入')));
      }
    } catch (e) {
      setState(() => _message = '匯入失敗：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(settingsJobsProvider).value ?? const <Job>[];

    return Scaffold(
      appBar: AppBar(title: const Text('校正班表')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedJobId,
                decoration: const InputDecoration(
                  labelText: '匯入到哪個工作',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('不指定')),
                  ...jobs.map((j) => DropdownMenuItem<int?>(value: j.id, child: Text(j.name))),
                ],
                onChanged: (v) => setState(() => _selectedJobId = v),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: [
                      const DataColumn(label: Text('姓名')),
                      for (var i = 0; i < _dates.length; i++)
                        DataColumn(
                          label: InkWell(
                            onTap: () => _pickDate(i),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(DateFormat('MM/dd').format(_dates[i])),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  tooltip: '刪除這一欄',
                                  onPressed: () => _removeColumn(i),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (var r = 0; r < _rows.length; r++)
                        DataRow(cells: [
                          DataCell(SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _rows[r].nameCtrl,
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            ),
                          )),
                          for (var i = 0; i < _dates.length; i++)
                            DataCell(SizedBox(
                              width: 90,
                              child: TextField(
                                controller: _rows[r].cellCtrls[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '-',
                                ),
                              ),
                            )),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            tooltip: '刪除這一列',
                            onPressed: () => _removeRow(r),
                          )),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('新增員工'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addColumn,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('新增日期'),
                  ),
                ],
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(_message!, style: const TextStyle(color: Colors.red)),
              ),
            if (widget.rawText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ExpansionTile(
                  title: const Text('辨識原文', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(widget.rawText!,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('確認匯入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
