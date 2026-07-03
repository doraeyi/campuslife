import 'package:flutter/material.dart';

enum PayType { hourly, monthly }

class ShiftPreset {
  final int id;
  final String label;
  final String startTime; // "HH:MM:SS"
  final String endTime;

  const ShiftPreset({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
  });

  String get displayStart => startTime.substring(0, 5);
  String get displayEnd => endTime.substring(0, 5);

  factory ShiftPreset.fromJson(Map<String, dynamic> json) => ShiftPreset(
        id: json['id'] as int,
        label: json['label'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      );
}

class Job {
  final int id;
  final String name;
  final Color color;
  final PayType payType;
  final double? hourlyRate;
  final double? monthlySalary;
  final int? payday;
  final double laborInsuranceFee;
  final double healthInsuranceFee;
  final List<ShiftPreset> presets;

  Job({
    required this.id,
    required this.name,
    required this.color,
    required this.payType,
    this.hourlyRate,
    this.monthlySalary,
    this.payday,
    this.laborInsuranceFee = 0,
    this.healthInsuranceFee = 0,
    this.presets = const [],
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as int,
      name: json['name'] as String,
      color: _colorFromHex(json['color'] as String),
      payType: (json['pay_type'] as String) == 'monthly' ? PayType.monthly : PayType.hourly,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble(),
      payday: json['payday'] as int?,
      laborInsuranceFee: (json['labor_insurance_fee'] as num?)?.toDouble() ?? 0,
      healthInsuranceFee: (json['health_insurance_fee'] as num?)?.toDouble() ?? 0,
      presets: (json['presets'] as List<dynamic>? ?? [])
          .map((p) => ShiftPreset.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

String colorToHex(Color color) {
  return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
