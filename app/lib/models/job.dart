import 'package:flutter/material.dart';

enum PayType { hourly, monthly }

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
