import 'package:flutter/material.dart';

import '../data/shift_type_colors.dart';
import '../data/taiwan_holidays_2026.dart';
import '../models/group_shift.dart';
import '../models/job.dart';
import '../models/shift.dart';
import '../services/api_client.dart';
import 'add_shift_screen.dart';

const shiftPresets = [
  (label: '早班', start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 16, minute: 0)),
  (label: '午班', start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 21, minute: 0)),
  (label: '晚班', start: TimeOfDay(hour: 17, minute: 0), end: TimeOfDay(hour: 22, minute: 0)),
  (label: '大夜', start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 6, minute: 0)),
];

String fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

TimeOfDay _parseTime(String hhmmss) {
  final parts = hhmmss.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

class DayBottomSheet extends StatefulWidget {
  const DayBottomSheet({
    super.key,
    required this.date,
    required this.shifts,
    this.groupShifts = const [],
    required this.jobs,
    required this.isViewingSelf,
    required this.onAdded,
  });

  final DateTime date;
  final List<Shift> shifts;
  final List<GroupShift> groupShifts;
  final List<Job> jobs;
  final bool isViewingSelf;
  final VoidCallback onAdded;

  @override
  State<DayBottomSheet> createState() => _DayBottomSheetState();
}

class _DayBottomSheetState extends State<DayBottomSheet> {
  final ApiClient _apiClient = ApiClient();
  bool _saving = false;
  Job? _selectedJob;

  @override
  void initState() {
    super.initState();
    _selectedJob = widget.jobs.isNotEmpty ? widget.jobs.first : null;
  }

  Future<void> _deleteShift(int shiftId) async {
    try {
      await _apiClient.deleteShift(shiftId);
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗:$e')));
    }
  }

  Future<void> _quickAddPreset(ShiftPreset preset) async {
    setState(() => _saving = true);
    try {
      final start = preset.displayStart.split(':');
      final end = preset.displayEnd.split(':');
      await _apiClient.createShift(
        date: widget.date,
        startTime: '${preset.startTime.substring(0, 5)}:00',
        endTime: '${preset.endTime.substring(0, 5)}:00',
        jobId: _selectedJob?.id,
        shiftType: preset.label,
      );
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗:$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quickAdd(String label, TimeOfDay start, TimeOfDay end) async {
    setState(() => _saving = true);
    try {
      await _apiClient.createShift(
        date: widget.date,
        startTime: fmtTime(start),
        endTime: fmtTime(end),
        jobId: _selectedJob?.id,
        shiftType: label,
      );
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗:$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.date.year}/${widget.date.month}/${widget.date.day}';
    final holiday = holidayNameFor(widget.date);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                if (holiday != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(holiday, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (widget.shifts.isNotEmpty)
              ...widget.shifts.map((shift) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: shift.job?.color ?? Colors.grey, radius: 8),
                    title: Text('${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}'),
                    subtitle: shift.job != null ? Text(shift.job!.name) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shift.shiftType != null)
                          Chip(
                            label: Text(shift.shiftType!),
                            backgroundColor: colorForShiftType(shift.shiftType),
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (widget.isViewingSelf)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteShift(shift.id),
                          ),
                      ],
                    ),
                  )),
            // ── 好友班表 ─────────────────────────────────────────────────
            if (widget.groupShifts.isNotEmpty) ...[
              const Divider(),
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6), shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('好友班表', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF8B5CF6),
                  )),
                ],
              ),
              const SizedBox(height: 4),
              ...widget.groupShifts.map((gs) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  radius: 16,
                  child: Text(
                    gs.owner.displayName.isNotEmpty
                        ? gs.owner.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '${gs.startTime.substring(0, 5)} - ${gs.endTime.substring(0, 5)}',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  gs.owner.displayName + (gs.job != null ? '・${gs.job!.name}' : ''),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              )),
            ],
            if (widget.isViewingSelf) ...[
              if (widget.shifts.isNotEmpty || widget.groupShifts.isNotEmpty) const Divider(),
              const Text('快速新增', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // ── 工作選擇器 ────────────────────────────────────────────
              if (widget.jobs.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.jobs.map((job) {
                      final selected = _selectedJob?.id == job.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(job.name),
                          selected: selected,
                          avatar: CircleAvatar(
                            backgroundColor: job.color,
                            radius: 8,
                          ),
                          onSelected: (_) => setState(() => _selectedJob = job),
                          selectedColor: job.color.withValues(alpha: 0.2),
                          side: selected
                              ? BorderSide(color: job.color, width: 1.5)
                              : BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── 班別快捷 ──────────────────────────────────────────────
              Builder(builder: (context) {
                final jobPresets = _selectedJob?.presets ?? [];
                if (jobPresets.isNotEmpty) {
                  // 顯示工作自訂班別
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: jobPresets.map((p) {
                      final chipColor = _selectedJob?.color ?? Colors.grey;
                      return ActionChip(
                        label: Text(
                          '${p.label}  ${p.displayStart}-${p.displayEnd}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor: chipColor,
                        onPressed: _saving ? null : () => _quickAddPreset(p),
                        avatar: Icon(Icons.add, color: Colors.white.withValues(alpha: 0.8), size: 14),
                      );
                    }).toList(),
                  );
                }
                // 無自訂班別 → 顯示預設班別
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: shiftPresets.map((p) {
                    final chipColor = colorForShiftType(p.label) ?? Colors.grey;
                    return ActionChip(
                      label: Text(p.label, style: const TextStyle(color: Colors.white)),
                      backgroundColor: chipColor,
                      onPressed: _saving ? null : () => _quickAdd(p.label, p.start, p.end),
                      avatar: Icon(Icons.add, color: Colors.white.withValues(alpha: 0.8), size: 16),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddShiftScreen()))
                      .then((added) {
                    if (added == true) widget.onAdded();
                  });
                },
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('自訂時間'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BatchAddSheet extends StatefulWidget {
  const BatchAddSheet({
    super.key,
    required this.selectedDays,
    required this.jobs,
    required this.apiClient,
    required this.onDone,
  });

  final Set<DateTime> selectedDays;
  final List<Job> jobs;
  final ApiClient apiClient;
  final VoidCallback onDone;

  @override
  State<BatchAddSheet> createState() => _BatchAddSheetState();
}

class _BatchAddSheetState extends State<BatchAddSheet> {
  Job? _job;
  String? _shiftType;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _job = widget.jobs.isNotEmpty ? widget.jobs.first : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final day in widget.selectedDays) {
        await widget.apiClient.createShift(
          date: day,
          startTime: fmtTime(_start),
          endTime: fmtTime(_end),
          jobId: _job?.id,
          shiftType: _shiftType,
        );
      }
      if (mounted) Navigator.pop(context);
      widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('新增失敗:$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('批次新增 (共 ${widget.selectedDays.length} 天)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 16),
            const Text('班別', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final jobPresets = _job?.presets ?? [];
              if (jobPresets.isNotEmpty) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: jobPresets.map((p) {
                    final selected = _shiftType == p.label;
                    final chipColor = _job?.color ?? Colors.grey;
                    return ChoiceChip(
                      label: Text('${p.label}  ${p.displayStart}-${p.displayEnd}',
                          style: TextStyle(color: selected ? Colors.white : null)),
                      selected: selected,
                      selectedColor: chipColor,
                      onSelected: (_) => setState(() {
                        _shiftType = p.label;
                        _start = _parseTime(p.startTime);
                        _end = _parseTime(p.endTime);
                      }),
                    );
                  }).toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: shiftPresets.map((p) {
                  final selected = _shiftType == p.label;
                  final chipColor = colorForShiftType(p.label) ?? Colors.grey;
                  return ChoiceChip(
                    label: Text(p.label, style: TextStyle(color: selected ? Colors.white : null)),
                    selected: selected,
                    selectedColor: chipColor,
                    onSelected: (_) => setState(() {
                      _shiftType = p.label;
                      _start = p.start;
                      _end = p.end;
                    }),
                  );
                }).toList(),
              );
            }),
            if (widget.jobs.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('工作', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.jobs.map((j) {
                  final selected = _job?.id == j.id;
                  return ChoiceChip(
                    label: Text(j.name),
                    selected: selected,
                    selectedColor: j.color,
                    labelStyle: TextStyle(color: selected ? Colors.white : null),
                    avatar: CircleAvatar(backgroundColor: j.color, radius: 6),
                    onSelected: (_) => setState(() {
                      _job = j;
                      _shiftType = null;
                    }),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('確認新增'),
            ),
          ],
        ),
      ),
    );
  }
}
