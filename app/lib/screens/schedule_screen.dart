import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/shift_type_colors.dart';
import '../data/taiwan_holidays_2026.dart';
import '../models/job.dart';
import '../models/shift.dart';
import '../services/api_client.dart';
import '../services/salary_calculator.dart';
import 'add_transaction_sheet.dart';
import 'schedule_widgets.dart';
import '../services/notification_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kWorkBlue   = Color(0xFF3B82F6);
const _kHolidayRed = Color(0xFFEF4444);
const _kTodayAmber = Color(0xFFF59E0B);
const _kNetGreen   = Color(0xFF10B981);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

double _shiftHoursLocal(Shift s) {
  int toMin(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
  var diff = toMin(s.endTime) - toMin(s.startTime);
  if (diff < 0) diff += 24 * 60;
  return diff / 60.0;
}

// ── ScheduleScreen ─────────────────────────────────────────────────────────
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Shift>> _shiftsFuture;
  Map<DateTime, List<Shift>> _shiftsByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());
  List<Job> _jobs = [];
  Job? _salaryJob;

  bool _multiSelectMode = false;
  final Set<DateTime> _multiSelectedDays = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _apiClient.fetchJobs();
      setState(() {
        _jobs = jobs;
        _salaryJob ??= jobs.isNotEmpty ? jobs.first : null;
      });
      await NotificationService().checkSalaryReminder(jobs);
    } catch (_) {}
  }

  void _refresh() {
    setState(() {
      _shiftsFuture = _apiClient.fetchShifts();
    });
    _shiftsFuture.then((shifts) {
      final map = <DateTime, List<Shift>>{};
      for (final shift in shifts) {
        final day = _dateOnly(shift.date);
        map.putIfAbsent(day, () => []).add(shift);
      }
      setState(() => _shiftsByDate = map);
    });
  }

  List<Shift> _shiftsFor(DateTime day) => _shiftsByDate[_dateOnly(day)] ?? [];

  void refresh() {
    _refresh();
    _loadJobs();
  }

  void _onDayTapped(DateTime day, DateTime focused) {
    if (_multiSelectMode) {
      final d = _dateOnly(day);
      setState(() {
        if (_multiSelectedDays.contains(d)) {
          _multiSelectedDays.remove(d);
        } else {
          _multiSelectedDays.add(d);
        }
      });
    } else {
      setState(() {
        _selectedDay = _dateOnly(day);
        _focusedDay = focused;
      });
      _showDaySheet(day);
    }
  }

  void _onDayLongPressed(DateTime day, DateTime focused) {
    setState(() {
      _multiSelectMode = true;
      _multiSelectedDays.clear();
      _multiSelectedDays.add(_dateOnly(day));
    });
  }

  void _cancelMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _multiSelectedDays.clear();
    });
  }

  void _showDaySheet(DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DayBottomSheet(
        date: day,
        shifts: _shiftsFor(day),
        jobs: _jobs,
        isViewingSelf: true,
        onAdded: () {
          _refresh();
          _loadJobs();
        },
      ),
    );
  }

  Future<void> _showBatchAddSheet() async {
    if (_multiSelectedDays.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BatchAddSheet(
        selectedDays: Set.from(_multiSelectedDays),
        jobs: _jobs,
        apiClient: _apiClient,
        onDone: () {
          _cancelMultiSelect();
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed month header ──────────────────────────────────────
            _MonthHeader(
              focusedDay: _focusedDay,
              jobs: _jobs,
              salaryJob: _salaryJob,
              onPrev: () => setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              }),
              onNext: () => setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              }),
              onJobSelected: (j) => setState(() => _salaryJob = j),
            ),

            // ── Scrollable content ──────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Shift>>(
                future: _shiftsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      error: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final monthShifts = _shiftsByDate.entries
                      .where((e) =>
                          e.key.year == _focusedDay.year &&
                          e.key.month == _focusedDay.month)
                      .expand((e) => e.value)
                      .toList();

                  final salaryShifts = monthShifts
                      .where((s) => s.jobId == _salaryJob?.id)
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        // ── Calendar card ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _CalendarCard(
                            focusedDay: _focusedDay,
                            selectedDay: _selectedDay,
                            multiSelectMode: _multiSelectMode,
                            multiSelectedDays: _multiSelectedDays,
                            shiftsFor: _shiftsFor,
                            colorScheme: colorScheme,
                            onDayTapped: _onDayTapped,
                            onDayLongPressed: _onDayLongPressed,
                            onPageChanged: (day) =>
                                setState(() => _focusedDay = day),
                          ),
                        ),

                        // ── Legend ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                          child: Row(
                            children: [
                              const _LegendDot(color: _kTodayAmber, label: '今天'),
                              const SizedBox(width: 12),
                              const _LegendDot(color: _kWorkBlue, label: '上班'),
                              const SizedBox(width: 12),
                              const _LegendDot(color: _kHolidayRed, label: '假日'),
                              const Spacer(),
                              if (!_multiSelectMode)
                                Text(
                                  '長按可批次選取',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colorScheme.outline),
                                ),
                            ],
                          ),
                        ),

                        // ── Multi-select banner ───────────────────────
                        if (_multiSelectMode)
                          _MultiSelectBanner(
                            count: _multiSelectedDays.length,
                            onCancel: _cancelMultiSelect,
                            onConfirm: _multiSelectedDays.isEmpty
                                ? null
                                : _showBatchAddSheet,
                          ),

                        // ── Shift summary ─────────────────────────────
                        if (monthShifts.isNotEmpty)
                          _ShiftSummaryCard(
                            focusedDay: _focusedDay,
                            monthShifts: monthShifts,
                            jobs: _jobs,
                          ),

                        // ── Salary card ───────────────────────────────
                        if (_salaryJob != null)
                          _SalaryCard(
                            selectedJob: _salaryJob!,
                            month: _focusedDay,
                            shiftsInMonth: salaryShifts,
                            apiClient: _apiClient,
                          ),

                        if (monthShifts.isEmpty && _salaryJob == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Text(
                              '點日期查看班次或新增',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colorScheme.outline),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Month header (fixed above scroll) ─────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.focusedDay,
    required this.jobs,
    required this.salaryJob,
    required this.onPrev,
    required this.onNext,
    required this.onJobSelected,
  });

  final DateTime focusedDay;
  final List<Job> jobs;
  final Job? salaryJob;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<Job> onJobSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 28,
                onPressed: onPrev,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${focusedDay.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${focusedDay.month.toString().padLeft(2, '0')}月',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 28,
                onPressed: onNext,
              ),
            ],
          ),
        ),
        // Job filter pills
        if (jobs.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final job = jobs[i];
                final selected = salaryJob?.id == job.id;
                return GestureDetector(
                  onTap: () => onJobSelected(job),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? job.color.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? job.color
                            : colorScheme.outlineVariant,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: job.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          job.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? job.color
                                : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Calendar card ──────────────────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.multiSelectMode,
    required this.multiSelectedDays,
    required this.shiftsFor,
    required this.colorScheme,
    required this.onDayTapped,
    required this.onDayLongPressed,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool multiSelectMode;
  final Set<DateTime> multiSelectedDays;
  final List<Shift> Function(DateTime) shiftsFor;
  final ColorScheme colorScheme;
  final void Function(DateTime, DateTime) onDayTapped;
  final void Function(DateTime, DateTime) onDayLongPressed;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TableCalendar<Shift>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: focusedDay,
          locale: 'zh_TW',
          eventLoader: shiftsFor,
          onDaySelected: onDayTapped,
          onDayLongPressed: onDayLongPressed,
          selectedDayPredicate: (day) => multiSelectMode
              ? multiSelectedDays.contains(_dateOnly(day))
              : _dateOnly(day) == selectedDay,
          onPageChanged: onPageChanged,
          rowHeight: 62,
          daysOfWeekHeight: 40,
          headerVisible: false,
          calendarStyle: const CalendarStyle(
            // Suppress default decorations; custom builders handle everything
            todayDecoration: BoxDecoration(),
            selectedDecoration: BoxDecoration(),
            markerDecoration: BoxDecoration(),
            outsideDaysVisible: true,
            cellMargin: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) => _DowCell(day: day),
            defaultBuilder: (context, day, _) =>
                _DayCell(day: day, shiftsFor: shiftsFor, colorScheme: colorScheme),
            outsideBuilder: (context, day, _) =>
                _DayCell(day: day, shiftsFor: shiftsFor, colorScheme: colorScheme, isOutside: true),
            todayBuilder: (context, day, _) =>
                _DayCell(day: day, shiftsFor: shiftsFor, colorScheme: colorScheme, isToday: true),
            selectedBuilder: (context, day, _) =>
                _DayCell(day: day, shiftsFor: shiftsFor, colorScheme: colorScheme, isSelected: true),
            markerBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ── Day-of-week header cell ────────────────────────────────────────────────
class _DowCell extends StatelessWidget {
  const _DowCell({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final isSat = day.weekday == DateTime.saturday;
    final isSun = day.weekday == DateTime.sunday;
    final color = isSun
        ? _kHolidayRed
        : isSat
            ? _kWorkBlue
            : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          labels[day.weekday - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Individual day cell ────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.shiftsFor,
    required this.colorScheme,
    this.isOutside = false,
    this.isToday = false,
    this.isSelected = false,
  });

  final DateTime day;
  final List<Shift> Function(DateTime) shiftsFor;
  final ColorScheme colorScheme;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final holiday = holidayNameFor(day);
    final isSat = day.weekday == DateTime.saturday;
    final isSun = day.weekday == DateTime.sunday;
    final isHoliday = holiday != null && !isOutside;

    // Determine number color
    Color numColor;
    if (isToday) {
      numColor = Colors.white;
    } else if (isSelected) {
      numColor = colorScheme.onPrimary;
    } else if (isOutside) {
      numColor = colorScheme.outline.withValues(alpha: 0.28);
    } else if (isHoliday || isSun) {
      numColor = _kHolidayRed;
    } else if (isSat) {
      numColor = _kWorkBlue;
    } else {
      numColor = colorScheme.onSurface;
    }

    // Circle background for today / selected
    BoxDecoration? circleDeco;
    if (isToday) {
      circleDeco = const BoxDecoration(color: _kTodayAmber, shape: BoxShape.circle);
    } else if (isSelected) {
      circleDeco = BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle);
    }

    final shifts = isOutside ? <Shift>[] : shiftsFor(day);
    final hasShift = shifts.isNotEmpty;
    final label = hasShift
        ? (shifts.first.shiftType ?? shifts.first.startTime.substring(0, 5))
        : null;
    final chipColor = hasShift
        ? (colorForShiftType(shifts.first.shiftType) ??
            shifts.first.job?.color ??
            _kWorkBlue)
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: circleDeco,
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      (isToday || isSelected) ? FontWeight.bold : FontWeight.w500,
                  color: numColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 14,
          child: hasShift
              ? Container(
                  constraints: const BoxConstraints(maxWidth: 46),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shifts.length > 1
                        ? '$label+${shifts.length - 1}'
                        : label!,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                )
              : isHoliday
                  ? Text(
                      '假',
                      style: TextStyle(
                        fontSize: 9,
                        color: _kHolidayRed.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Legend dot ─────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ── Multi-select banner ────────────────────────────────────────────────────
class _MultiSelectBanner extends StatelessWidget {
  const _MultiSelectBanner({
    required this.count,
    required this.onCancel,
    this.onConfirm,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已選 $count 天，長按繼續加選',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('設定班別'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shift summary card ─────────────────────────────────────────────────────
class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({
    required this.focusedDay,
    required this.monthShifts,
    required this.jobs,
  });

  final DateTime focusedDay;
  final List<Shift> monthShifts;
  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group shifts by jobId
    final byJob = <int, List<Shift>>{};
    for (final s in monthShifts) {
      byJob.putIfAbsent(s.jobId ?? -1, () => []).add(s);
    }

    final jobMap = {for (final j in jobs) j.id: j};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Row(
              children: [
                Text(
                  '班表摘要',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
                const Spacer(),
                Text(
                  '${focusedDay.month}月',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Per-job rows
            ...byJob.entries.map((entry) {
              final job = jobMap[entry.key] ??
                  entry.value.firstOrNull?.job;
              final shifts = entry.value;
              final totalHours =
                  shifts.fold(0.0, (sum, s) => sum + _shiftHoursLocal(s));

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: job?.color ?? _kWorkBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        job?.name ?? '工作',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _StatPill(label: '${shifts.length} 班'),
                    const SizedBox(width: 8),
                    _StatPill(
                        label: '${totalHours.toStringAsFixed(0)} 小時'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Salary card ────────────────────────────────────────────────────────────
class _SalaryCard extends StatefulWidget {
  const _SalaryCard({
    required this.selectedJob,
    required this.month,
    required this.shiftsInMonth,
    required this.apiClient,
  });

  final Job selectedJob;
  final List<Shift> shiftsInMonth;
  final DateTime month;
  final ApiClient apiClient;

  @override
  State<_SalaryCard> createState() => _SalaryCardState();
}

class _SalaryCardState extends State<_SalaryCard> {
  bool _isSaving = false;
  bool _isOpeningSheet = false;

  Future<void> _openSalarySheet(SalaryBreakdown breakdown) async {
    setState(() => _isOpeningSheet = true);
    try {
      final cards = await widget.apiClient.fetchCards();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionSheet(
          cards: cards,
          prefillAmount: breakdown.net,
          prefillType: 'income',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入卡片失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningSheet = false);
    }
  }

  Future<void> _addToIncome(SalaryBreakdown breakdown) async {
    setState(() => _isSaving = true);
    try {
      await widget.apiClient.createIncome(
        jobId: widget.selectedJob.id,
        month:
            '${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}',
        grossAmount: breakdown.gross,
        deductionAmount: breakdown.insuranceDeduction,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已新增到收入紀錄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final breakdown = calculateSalary(
      shiftsInMonth: widget.shiftsInMonth,
      job: widget.selectedJob,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Text(
                  '薪資預估',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.selectedJob.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.selectedJob.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.shiftsInMonth.length} 班 · ${breakdown.totalHours.toStringAsFixed(0)} 小時',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Amount row ──
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _AmountColumn(
                      label: '應領',
                      amount: breakdown.gross,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  VerticalDivider(
                    color: colorScheme.outlineVariant,
                    thickness: 1,
                    indent: 6,
                    endIndent: 6,
                  ),
                  Expanded(
                    child: _AmountColumn(
                      label: '扣款',
                      amount: -breakdown.insuranceDeduction,
                      color: _kHolidayRed,
                    ),
                  ),
                  VerticalDivider(
                    color: colorScheme.outlineVariant,
                    thickness: 1,
                    indent: 6,
                    endIndent: 6,
                  ),
                  Expanded(
                    child: _AmountColumn(
                      label: '實領',
                      amount: breakdown.net,
                      color: _kNetGreen,
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── CTAs ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addToIncome(breakdown),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('記收入紀錄',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _isOpeningSheet ? null : () => _openSalarySheet(breakdown),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _kNetGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isOpeningSheet
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            '記帳入帳',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  final String label;
  final double amount;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final sign = amount < 0 ? '-' : '';
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '$sign\$${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 18 : 16,
          ),
        ),
      ],
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('讀取失敗：$error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
