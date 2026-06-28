import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shift.dart';

class ApiClient {
  // 實機測試時換成電腦的區網 IP,例如 http://192.168.1.10:8000
  static const String baseUrl = 'http://localhost:8000';

  Future<List<Shift>> fetchShifts() async {
    final response = await http.get(Uri.parse('$baseUrl/schedule'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load shifts: ${response.statusCode}');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Shift.fromJson(json)).toList();
  }
}
