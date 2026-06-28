import 'package:home_widget/home_widget.dart';

import '../models/shift.dart';

class WidgetService {
  static const String appGroupId = 'group.com.campuslife.app';
  static const String iOSWidgetName = 'CampusLifeWidget';

  static Future<void> updateNextShift(List<Shift> shifts) async {
    await HomeWidget.setAppGroupId(appGroupId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = shifts.where((s) => !s.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (upcoming.isEmpty) {
      await HomeWidget.saveWidgetData<String>('next_shift_text', '目前沒有班表');
    } else {
      final shift = upcoming.first;
      final text =
          '${shift.date.month}/${shift.date.day} ${shift.startTime.substring(0, 5)}-${shift.endTime.substring(0, 5)}';
      await HomeWidget.saveWidgetData<String>('next_shift_text', text);
    }

    await HomeWidget.updateWidget(iOSName: iOSWidgetName);
  }
}
