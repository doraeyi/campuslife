import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/friend_shift.dart';
import '../services/api_client.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedShifts = _shiftsFor(_selectedDay);

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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TableCalendar<FriendShift>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    locale: 'zh_TW',
                    eventLoader: _shiftsFor,
                    selectedDayPredicate: (day) => _dateOnly(day) == _selectedDay,
                    onDaySelected: (day, focused) {
                      setState(() {
                        _selectedDay = _dateOnly(day);
                        _focusedDay = focused;
                      });
                    },
                    onPageChanged: (day) => setState(() => _focusedDay = day),
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${_selectedDay.month}/${_selectedDay.day} 的班次',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 4),
                if (selectedShifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text('這天沒有分享的班次'),
                  )
                else
                  ...selectedShifts.map((shift) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: shift.job?.color ?? Colors.grey,
                          radius: 8,
                        ),
                        title: Text('${shift.startTime} - ${shift.endTime}'),
                        subtitle: shift.job != null ? Text(shift.job!.name) : null,
                        trailing: shift.shiftType != null ? Chip(label: Text(shift.shiftType!)) : null,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}
