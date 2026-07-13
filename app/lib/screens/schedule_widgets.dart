import 'package:flutter/material.dart';

import '../data/shift_type_colors.dart';
import '../data/taiwan_holidays_2026.dart';
import '../models/job.dart';
import '../models/roster.dart';
import '../models/shift.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import 'add_shift_screen.dart';

const shiftPresets = [
  (
    label: '早班',
    start: TimeOfDay(hour: 8, minute: 0),
    end: TimeOfDay(hour: 16, minute: 0)
  ),
  (
    label: '午班',
    start: TimeOfDay(hour: 13, minute: 0),
    end: TimeOfDay(hour: 21, minute: 0)
  ),
  (
    label: '晚班',
    start: TimeOfDay(hour: 17, minute: 0),
    end: TimeOfDay(hour: 22, minute: 0)
  ),
  (
    label: '大夜',
    start: TimeOfDay(hour: 22, minute: 0),
    end: TimeOfDay(hour: 6, minute: 0)
  ),
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
    required this.jobs,
    required this.isViewingSelf,
    required this.onAdded,
    this.initialJob,
  });

  final DateTime date;
  final List<Shift> shifts;
  final List<Job> jobs;
  final bool isViewingSelf;
  final VoidCallback onAdded;
  final Job? initialJob;

  @override
  State<DayBottomSheet> createState() => _DayBottomSheetState();
}

class _DayBottomSheetState extends State<DayBottomSheet> {
  final ApiClient _apiClient = ApiClient();
  bool _saving = false;
  Job? _selectedJob;

  List<RosterShift> _rosterShifts = [];
  bool _rosterLoading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialJob != null &&
            widget.jobs.any((j) => j.id == widget.initialJob!.id)
        ? widget.initialJob
        : null;
    _selectedJob =
        initial ?? (widget.jobs.isNotEmpty ? widget.jobs.first : null);
    _loadRosterShifts();
  }

  Future<void> _loadRosterShifts() async {
    if (_selectedJob == null) {
      setState(() => _rosterShifts = []);
      return;
    }
    setState(() => _rosterLoading = true);
    try {
      final shifts = await _apiClient.fetchRosterShifts(
        widget.date,
        widget.date,
        jobId: _selectedJob!.id,
      );
      if (mounted) setState(() => _rosterShifts = shifts);
    } catch (_) {
      if (mounted) setState(() => _rosterShifts = []);
    } finally {
      if (mounted) setState(() => _rosterLoading = false);
    }
  }

  void _selectJob(Job job) {
    setState(() => _selectedJob = job);
    _loadRosterShifts();
  }

  /// 把班別預設依「跟現在的關聯程度」排序：目前這班排第一個，接著是未來
  /// 會輪到的班別；剛換班沒多久（60 分鐘內）大家還是會覺得上一班的人比較
  /// 相關，這時候讓上一班排到最前面。
  List<ShiftPreset> _rankedPresets(List<ShiftPreset> presets, DateTime now) {
    if (presets.length <= 1) return presets;
    const graceMinutes = 60;
    final nowMinutes = now.hour * 60 + now.minute;

    int startMinutes(ShiftPreset p) {
      final parts = p.startTime.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    int elapsedSinceStart(ShiftPreset p) {
      final diff = nowMinutes - startMinutes(p);
      return diff < 0 ? diff + 24 * 60 : diff;
    }

    final sorted = List<ShiftPreset>.from(presets)
      ..sort((a, b) => startMinutes(a).compareTo(startMinutes(b)));

    var currentIndex = 0;
    var minElapsed = elapsedSinceStart(sorted.first);
    for (var i = 1; i < sorted.length; i++) {
      final elapsed = elapsedSinceStart(sorted[i]);
      if (elapsed < minElapsed) {
        minElapsed = elapsed;
        currentIndex = i;
      }
    }

    final rotated = [
      for (var i = 0; i < sorted.length; i++)
        sorted[(currentIndex + i) % sorted.length],
    ];

    if (minElapsed < graceMinutes) {
      rotated.insert(0, rotated.removeLast());
    }
    return rotated;
  }

  int _toMinutes(String hhmmss) {
    final parts = hhmmss.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int _durationMinutes(int start, int end) =>
      end > start ? end - start : (24 * 60 - start) + end;

  /// 兩個(可能跨夜)時間區間實際重疊的分鐘數，跨夜的區間用往前/往後平移
  /// 一天的方式各算一次，取重疊最多的那個對齊方式。
  int _overlapMinutes(int aStart, int aDur, int bStart, int bDur) {
    var best = 0;
    for (final shift in [-24 * 60, 0, 24 * 60]) {
      final bs = bStart + shift;
      final overlapStart = aStart > bs ? aStart : bs;
      final overlapEnd =
          (aStart + aDur) < (bs + bDur) ? (aStart + aDur) : (bs + bDur);
      final overlap = overlapEnd - overlapStart;
      if (overlap > best) best = overlap;
    }
    return best;
  }

  /// 匯入的班表常常對不到精準的班別預設(OCR 讀到的時間跟預設差一點、或
  /// 這個工作根本沒設定完全相符的班別)，這時候不要顯示原始時間，改看實際
  /// 時間跟哪個班別預設重疊最多，歸類到那一班；完全沒重疊就退回用開始時間
  /// 最接近的班別。真的一個班別都沒有(這個工作沒設定過)才顯示原始時間。
  ShiftPreset? _bestPreset(RosterShift s, List<ShiftPreset> presets) {
    if (presets.isEmpty || s.startTime == null || s.endTime == null)
      return null;
    final sStart = _toMinutes(s.startTime!);
    final sDur = _durationMinutes(sStart, _toMinutes(s.endTime!));

    ShiftPreset? bestByOverlap;
    var bestOverlap = 0;
    for (final p in presets) {
      final pStart = _toMinutes(p.startTime);
      final pDur = _durationMinutes(pStart, _toMinutes(p.endTime));
      final overlap = _overlapMinutes(sStart, sDur, pStart, pDur);
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestByOverlap = p;
      }
    }
    if (bestByOverlap != null) return bestByOverlap;

    ShiftPreset? closest;
    var closestDist = 24 * 60;
    for (final p in presets) {
      final diff = (sStart - _toMinutes(p.startTime)).abs();
      final dist = diff > 12 * 60 ? 24 * 60 - diff : diff;
      if (dist < closestDist) {
        closestDist = dist;
        closest = p;
      }
    }
    return closest;
  }

  String _shiftLabel(RosterShift s) {
    if (s.shiftType != null) return s.shiftType!;
    final best = _bestPreset(s, _selectedJob?.presets ?? []);
    if (best != null) return best.label;
    return '${s.startTime}-${s.endTime}';
  }

  /// 休假(start/end 皆空)的人不列進「誰上班」，只看實際有上班的人。
  List<RosterShift> get _workingRosterShifts => _rosterShifts
      .where((s) => s.startTime != null && s.endTime != null)
      .toList();

  List<RosterShift> get _sortedRosterShifts {
    final presets = _selectedJob?.presets ?? [];
    final working = _workingRosterShifts;
    if (presets.isEmpty) return working;
    final order = _rankedPresets(presets, DateTime.now());
    final rank = {for (var i = 0; i < order.length; i++) order[i].label: i};
    final sorted = List<RosterShift>.from(working);
    sorted.sort((a, b) {
      final aLabel = _bestPreset(a, presets)?.label;
      final bLabel = _bestPreset(b, presets)?.label;
      return (rank[aLabel] ?? order.length)
          .compareTo(rank[bLabel] ?? order.length);
    });
    return sorted;
  }

  Future<void> _deleteShift(int shiftId) async {
    try {
      await _apiClient.deleteShift(shiftId);
      await NotificationService().cancelShiftReminder(shiftId);
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刪除失敗:$e')));
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失敗:$e')));
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('失敗:$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.date.year}/${widget.date.month}/${widget.date.day}';
    final holiday = holidayNameFor(widget.date);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(dateStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  if (holiday != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(holiday,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── 工作選擇器(切換要看哪個工作地點的同事班表)──────────────
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
                          onSelected: (_) => _selectJob(job),
                          selectedColor: job.color.withValues(alpha: 0.2),
                          side: selected
                              ? BorderSide(color: job.color, width: 1.5)
                              : BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 誰上班 ──────────────────────────────────────────────
                const Text('誰上班',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_rosterLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                else if (_sortedRosterShifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('這個工作今天沒有人上班',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 13)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortedRosterShifts.map((s) {
                      final label = _shiftLabel(s);
                      return Chip(
                        label: Text('${s.employeeName} · $label',
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            (colorForShiftType(label) ?? _selectedJob?.color)
                                ?.withValues(alpha: 0.15),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                const Divider(),
              ],

              const Text('我的班次', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (widget.shifts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('這天還沒有排班',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13)),
                ),
              if (widget.shifts.isNotEmpty)
                ...widget.shifts.map((shift) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          backgroundColor: shift.job?.color ?? Colors.grey,
                          radius: 8),
                      title: Text(
                          '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}'),
                      subtitle:
                          shift.job != null ? Text(shift.job!.name) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (shift.shiftType != null)
                            Chip(
                              label: Text(shift.shiftType!),
                              backgroundColor:
                                  colorForShiftType(shift.shiftType),
                              labelStyle: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (widget.isViewingSelf)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => _deleteShift(shift.id),
                            ),
                        ],
                      ),
                    )),
              if (widget.isViewingSelf) ...[
                const Divider(),
                const Text('快速新增',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

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
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: chipColor,
                          onPressed: _saving ? null : () => _quickAddPreset(p),
                          avatar: Icon(Icons.add,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 14),
                        );
                      }).toList(),
                    );
                  }
                  // 無自訂班別 → 顯示預設班別
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: shiftPresets.map((p) {
                      final chipColor =
                          colorForShiftType(p.label) ?? Colors.grey;
                      return ActionChip(
                        label: Text(p.label,
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: chipColor,
                        onPressed: _saving
                            ? null
                            : () => _quickAdd(p.label, p.start, p.end),
                        avatar: Icon(Icons.add,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 16),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AddShiftScreen()))
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('新增失敗:$e')));
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                      label: Text(
                          '${p.label}  ${p.displayStart}-${p.displayEnd}',
                          style:
                              TextStyle(color: selected ? Colors.white : null)),
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
                    label: Text(p.label,
                        style:
                            TextStyle(color: selected ? Colors.white : null)),
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
                    labelStyle:
                        TextStyle(color: selected ? Colors.white : null),
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
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('確認新增'),
            ),
          ],
        ),
      ),
    );
  }
}
