import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/roster.dart';
import '../services/api_client.dart';

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// 團隊班表檢視：讀取 [ApiClient.fetchRosterShifts] 顯示整週所有同事的班，
/// 資料來自排班表照片匯入（見 features/roster_import/），單純唯讀表格，
/// 不像個人班表用 table_calendar——形狀本質是表格，不是逐日格子。
class TeamRosterPage extends HookConsumerWidget {
  const TeamRosterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = useState(_mondayOf(DateTime.now()));
    final weekDates = List.generate(7, (i) => weekStart.value.add(Duration(days: i)));

    final shiftsSnapshot = useFuture(useMemoized(
      () => ApiClient().fetchRosterShifts(weekStart.value, weekDates.last),
      [weekStart.value],
    ));

    final shifts = shiftsSnapshot.data ?? const <RosterShift>[];
    final byEmployee = <String, Map<String, RosterShift>>{};
    for (final s in shifts) {
      byEmployee.putIfAbsent(s.employeeName, () => {})[_dateKey(s.date)] = s;
    }
    final employeeNames = byEmployee.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('團隊班表')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () =>
                        weekStart.value = weekStart.value.subtract(const Duration(days: 7)),
                  ),
                  Text(
                    '${DateFormat('MM/dd').format(weekStart.value)} - ${DateFormat('MM/dd').format(weekDates.last)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => weekStart.value = weekStart.value.add(const Duration(days: 7)),
                  ),
                ],
              ),
            ),
            if (shiftsSnapshot.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (shiftsSnapshot.hasError)
              Expanded(child: Center(child: Text('載入失敗：${shiftsSnapshot.error}')))
            else if (employeeNames.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('這週還沒有匯入班表', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('姓名')),
                        for (final d in weekDates) DataColumn(label: Text(DateFormat('MM/dd').format(d))),
                      ],
                      rows: [
                        for (final name in employeeNames)
                          DataRow(cells: [
                            DataCell(Text(name)),
                            for (final d in weekDates)
                              DataCell(_ShiftCell(shift: byEmployee[name]![_dateKey(d)])),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCell extends StatelessWidget {
  const _ShiftCell({required this.shift});

  final RosterShift? shift;

  @override
  Widget build(BuildContext context) {
    if (shift == null) return const Text('', style: TextStyle(color: Colors.grey));
    if (shift!.startTime == null || shift!.endTime == null) {
      return const Text('休', style: TextStyle(color: Colors.grey));
    }
    return Text('${shift!.startTime}-${shift!.endTime}', style: const TextStyle(fontSize: 12));
  }
}
