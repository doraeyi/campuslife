import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shift.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.0.16:8000';

  Future<List<Shift>> fetchShifts() async {
    final response = await http.get(Uri.parse('$baseUrl/schedule'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load shifts: ${response.statusCode}');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Shift.fromJson(json)).toList();
  }

  Future<void> createShift({
    required DateTime date,
    required String startTime,
    required String endTime,
    String? note,
  }) async {
    final body = jsonEncode({
      'date': date.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'note': note,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/schedule'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create shift: ${response.statusCode}');
    }
  }
}
