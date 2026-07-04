import '../data/taiwan_holidays_2026.dart';
import '../models/job.dart';
import '../models/shift.dart';

const _holidayMultiplier = 2.0;

class SalaryBreakdown {
  final double basePay;
  final double holidayBonus;
  final double insuranceDeduction;
  final double totalHours;
  final int holidayShiftCount;
  final int shiftCount;

  const SalaryBreakdown({
    required this.basePay,
    required this.holidayBonus,
    required this.insuranceDeduction,
    required this.totalHours,
    required this.holidayShiftCount,
    required this.shiftCount,
  });

  double get gross => basePay + holidayBonus;

  double get net => gross - insuranceDeduction;
}

double _shiftHours(Shift shift) {
  Duration parse(String time) {
    final parts = time.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  var diff = parse(shift.endTime) - parse(shift.startTime);
  if (diff.isNegative) {
    diff += const Duration(hours: 24);
  }
  return diff.inMinutes / 60;
}

SalaryBreakdown calculateSalary({
  required List<Shift> shiftsInMonth,
  required Job job,
}) {
  final insurance = job.laborInsuranceFee + job.healthInsuranceFee + job.welfareFee;

  if (job.payType == PayType.monthly) {
    final holidayShifts = shiftsInMonth.where((s) => holidayNameFor(s.date) != null).toList();
    final monthlySalary = job.monthlySalary ?? 0;
    final dailyRate = monthlySalary / 30;
    final bonus = holidayShifts.length * dailyRate * (_holidayMultiplier - 1);
    return SalaryBreakdown(
      basePay: monthlySalary,
      holidayBonus: bonus,
      insuranceDeduction: insurance,
      totalHours: shiftsInMonth.fold(0.0, (sum, s) => sum + _shiftHours(s)),
      holidayShiftCount: holidayShifts.length,
      shiftCount: shiftsInMonth.length,
    );
  }

  double basePay = 0;
  double holidayBonus = 0;
  double totalHours = 0;
  var holidayShiftCount = 0;
  final hourlyRate = job.hourlyRate ?? 0;

  for (final shift in shiftsInMonth) {
    final hours = _shiftHours(shift);
    totalHours += hours;
    final pay = hours * hourlyRate;
    if (holidayNameFor(shift.date) != null) {
      holidayShiftCount++;
      basePay += pay;
      holidayBonus += pay * (_holidayMultiplier - 1);
    } else {
      basePay += pay;
    }
  }

  return SalaryBreakdown(
    basePay: basePay,
    holidayBonus: holidayBonus,
    insuranceDeduction: insurance,
    totalHours: totalHours,
    holidayShiftCount: holidayShiftCount,
    shiftCount: shiftsInMonth.length,
  );
}
