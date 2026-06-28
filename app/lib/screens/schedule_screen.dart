import 'package:flutter/material.dart';

import '../models/shift.dart';
import '../services/api_client.dart';
import '../services/widget_service.dart';
import 'add_shift_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Shift>> _shiftsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _shiftsFuture = _apiClient.fetchShifts();
    });
    _shiftsFuture.then(WidgetService.updateNextShift).catchError((_) {});
  }

  Future<void> _openAddShift() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddShiftScreen()),
    );
    if (added == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的班表')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddShift,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Shift>>(
        future: _shiftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗:${snapshot.error}'));
          }
          final shifts = snapshot.data ?? [];
          if (shifts.isEmpty) {
            return const Center(child: Text('目前沒有班表'));
          }
          return ListView.builder(
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return ListTile(
                title: Text('${shift.date.year}/${shift.date.month}/${shift.date.day}'),
                subtitle: Text('${shift.startTime} - ${shift.endTime}'),
                trailing: shift.note != null ? Text(shift.note!) : null,
              );
            },
          );
        },
      ),
    );
  }
}
