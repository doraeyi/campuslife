import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/taiwan_holidays_2026.dart';
import '../models/friend_shift.dart';
import '../services/api_client.dart';

const _kWorkBlue   = Color(0xFF3B82F6);
const _kHolidayRed = Color(0xFFEF4444);
const _kTodayAmber = Color(0xFFF59E0B);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class FriendScheduleScreen extends StatefulWidget {
  const FriendScheduleScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  final int friendId;
  final String friendName;

  @override
  State<FriendScheduleScreen> createState() => _FriendScheduleScreenState();
}

class _FriendScheduleScreenState extends State<FriendScheduleScreen> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<FriendShift>> _shiftsFuture;
  Map<DateTime, List<FriendShift>> _shiftsByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _shiftsFuture = _apiClient.fetchFriendShifts(widget.friendId);
    });
    _shiftsFuture.then((shifts) {
      final map = <DateTime, List<FriendShift>>{};
      for (final shift in shifts) {
        final day = _dateOnly(shift.date);
        map.putIfAbsent(day, () => []).add(shift);
      }
      if (mounted) setState(() => _shiftsByDate = map);
    });
  }

  List<FriendShift> _shiftsFor(DateTime day) => _shiftsByDate[_dateOnly(day)] ?? [];

  void _onDayTapped(DateTime day, DateTime focused) {
    setState(() {
      _selectedDay = _dateOnly(day);
      _focusedDay = focused;
    });
    final shifts = _shiftsFor(day);
    if (shifts.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DayShiftsSheet(day: day, shifts: shifts, friendName: widget.friendName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.friendName} 的班表')),
      body: FutureBuilder<List<FriendShift>>(
        future: _shiftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '載入失敗:${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            );
          }
          if ((snapshot.data ?? []).isEmpty) {
            return const Center(child: Text('對方目前沒有分享任何班表給你'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _FriendMonthHeader(
                  focusedDay: _focusedDay,
                  onPrev: () => setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  }),
                  onNext: () => setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  }),
                ),
                const SizedBox(height: 8),
                Container(
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
                    child: TableCalendar<FriendShift>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      locale: 'zh_TW',
                      eventLoader: _shiftsFor,
                      selectedDayPredicate: (day) => _dateOnly(day) == _selectedDay,
                      onDaySelected: _onDayTapped,
                      onPageChanged: (day) => setState(() => _focusedDay = day),
                      rowHeight: 56,
                      daysOfWeekHeight: 36,
                      headerVisible: false,
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(),
                        selectedDecoration: BoxDecoration(),
                        markerDecoration: BoxDecoration(),
                        outsideDaysVisible: true,
                        cellMargin: EdgeInsets.zero,
                      ),
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) => _FriendDowCell(day: day),
                        defaultBuilder: (context, day, _) =>
                            _FriendDayCell(day: day, shiftsFor: _shiftsFor, colorScheme: colorScheme),
                        outsideBuilder: (context, day, _) => _FriendDayCell(
                            day: day, shiftsFor: _shiftsFor, colorScheme: colorScheme, isOutside: true),
                        todayBuilder: (context, day, _) => _FriendDayCell(
                            day: day, shiftsFor: _shiftsFor, colorScheme: colorScheme, isToday: true),
                        selectedBuilder: (context, day, _) => _FriendDayCell(
                            day: day, shiftsFor: _shiftsFor, colorScheme: colorScheme, isSelected: true),
                        markerBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '點日期查看當天班次',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Month header (prev/next arrows, no format toggle) ─────────────────────
class _FriendMonthHeader extends StatelessWidget {
  const _FriendMonthHeader({
    required this.focusedDay,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime focusedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), iconSize: 26, onPressed: onPrev),
        Expanded(
          child: Text(
            '${focusedDay.year}年 ${focusedDay.month}月',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), iconSize: 26, onPressed: onNext),
      ],
    );
  }
}

class _FriendDowCell extends StatelessWidget {
  const _FriendDowCell({required this.day});
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(labels[day.weekday - 1],
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

// ── Day cell showing job-colored chip, matching the personal schedule ─────
class _FriendDayCell extends StatelessWidget {
  const _FriendDayCell({
    required this.day,
    required this.shiftsFor,
    required this.colorScheme,
    this.isOutside = false,
    this.isToday = false,
    this.isSelected = false,
  });

  final DateTime day;
  final List<FriendShift> Function(DateTime) shiftsFor;
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

    BoxDecoration? circleDeco;
    if (isToday) {
      circleDeco = const BoxDecoration(color: _kTodayAmber, shape: BoxShape.circle);
    } else if (isSelected) {
      circleDeco = BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle);
    }

    final shifts = isOutside ? <FriendShift>[] : shiftsFor(day);
    final hasShift = shifts.isNotEmpty;
    final label = hasShift ? (shifts.first.shiftType ?? shifts.first.startTime) : null;
    final chipColor = hasShift ? (shifts.first.job?.color ?? _kWorkBlue) : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: circleDeco,
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.w500,
              color: numColor,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 14,
          child: hasShift
              ? Container(
                  constraints: const BoxConstraints(maxWidth: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    shifts.length > 1 ? '$label+${shifts.length - 1}' : label!,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                )
              : isHoliday
                  ? Text('假',
                      style: TextStyle(
                          fontSize: 9, color: _kHolidayRed.withValues(alpha: 0.65), fontWeight: FontWeight.w600))
                  : null,
        ),
      ],
    );
  }
}

// ── Read-only bottom sheet for a single day's shared shifts ──────────────
class _DayShiftsSheet extends StatelessWidget {
  const _DayShiftsSheet({required this.day, required this.shifts, required this.friendName});

  final DateTime day;
  final List<FriendShift> shifts;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${day.month}/${day.day}・$friendName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            ...shifts.map((shift) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: shift.job?.color ?? Colors.grey, radius: 8),
                  title: Text('${shift.startTime} - ${shift.endTime}'),
                  subtitle: shift.job != null ? Text(shift.job!.name) : null,
                  trailing: shift.shiftType != null ? Chip(label: Text(shift.shiftType!)) : null,
                )),
          ],
        ),
      ),
    );
  }
}
