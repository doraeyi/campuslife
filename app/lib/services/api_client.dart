import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/income.dart';
import '../models/job.dart';
import '../models/settings_models.dart';
import '../models/shift.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.0.16:8000';

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Shifts ───────────────────────────────────────────────────────────────

  Future<List<Shift>> fetchShifts() async {
    final response = await http.get(Uri.parse('$baseUrl/schedule'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('Failed to load shifts: ${response.statusCode}');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Shift.fromJson(json)).toList();
  }

  Future<List<Shift>> fetchFriendShifts(int friendUserId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/schedule/friend/$friendUserId'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Failed to load friend shifts: ${response.statusCode}');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Shift.fromJson(json)).toList();
  }

  Future<void> createShift({
    required DateTime date,
    required String startTime,
    required String endTime,
    int? jobId,
    String? shiftType,
    String? note,
  }) async {
    final body = jsonEncode({
      'date': date.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'job_id': jobId,
      'shift_type': shiftType,
      'note': note,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/schedule'),
      headers: await _authHeaders(),
      body: body,
    );
    if (response.statusCode != 200) throw Exception('Failed to create shift: ${response.statusCode}');
  }

  Future<void> deleteShift(int shiftId) async {
    final response = await http.delete(Uri.parse('$baseUrl/schedule/$shiftId'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('刪除班表失敗');
  }

  // ── Jobs ─────────────────────────────────────────────────────────────────

  Future<List<Job>> fetchJobs() async {
    final response = await http.get(Uri.parse('$baseUrl/jobs'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('Failed to load jobs: ${response.statusCode}');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Job.fromJson(json)).toList();
  }

  Future<Job> createJob({
    required String name,
    required String colorHex,
    required PayType payType,
    double? hourlyRate,
    double? monthlySalary,
    int? payday,
    double laborInsuranceFee = 0,
    double healthInsuranceFee = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/jobs'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        'color': colorHex,
        'pay_type': payType == PayType.monthly ? 'monthly' : 'hourly',
        'hourly_rate': hourlyRate,
        'monthly_salary': monthlySalary,
        'payday': payday,
        'labor_insurance_fee': laborInsuranceFee,
        'health_insurance_fee': healthInsuranceFee,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to create job: ${response.statusCode}');
    return Job.fromJson(jsonDecode(response.body));
  }

  Future<Job> updateJob(
    int id, {
    required String name,
    required String colorHex,
    required PayType payType,
    double? hourlyRate,
    double? monthlySalary,
    int? payday,
    double laborInsuranceFee = 0,
    double healthInsuranceFee = 0,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/jobs/$id'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        'color': colorHex,
        'pay_type': payType == PayType.monthly ? 'monthly' : 'hourly',
        'hourly_rate': hourlyRate,
        'monthly_salary': monthlySalary,
        'payday': payday,
        'labor_insurance_fee': laborInsuranceFee,
        'health_insurance_fee': healthInsuranceFee,
      }),
    );
    if (response.statusCode != 200) throw Exception('更新工作失敗');
    return Job.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteJob(int jobId) async {
    final response = await http.delete(Uri.parse('$baseUrl/jobs/$jobId'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('刪除工作失敗');
  }

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<UserProfile> fetchMe() async {
    final response = await http.get(Uri.parse('$baseUrl/users/me'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('載入個人資料失敗');
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> updateMe({String? name, String? picture}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (picture != null) body['picture'] = picture;
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw Exception('更新個人資料失敗');
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateProfile({required String displayName}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _authHeaders(),
      body: jsonEncode({'display_name': displayName}),
    );
    if (response.statusCode != 200) throw Exception('更新失敗');
    final data = jsonDecode(response.body);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('auth_user');
    if (stored != null) {
      final user = jsonDecode(stored) as Map<String, dynamic>;
      user['display_name'] = data['display_name'];
      await prefs.setString('auth_user', jsonEncode(user));
    }
  }

  Future<bool> fetchHasPassword() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/has-password'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) return true;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['has_password'] as bool;
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me/password'),
      headers: await _authHeaders(),
      body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['detail'] ?? '密碼更新失敗');
    }
  }

  // ── Google Link ───────────────────────────────────────────────────────────

  Future<GoogleLinkStatus> fetchGoogleLink() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/google'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) return const GoogleLinkStatus(linked: false);
    return GoogleLinkStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> unlinkGoogle() async {
    await http.delete(Uri.parse('$baseUrl/users/me/google'), headers: await _authHeaders());
  }

  // ── LINE Link ─────────────────────────────────────────────────────────────

  Future<LineLinkStatus> fetchLineLink() async {
    final response = await http.get(Uri.parse('$baseUrl/line/link'), headers: await _authHeaders());
    if (response.statusCode != 200) return const LineLinkStatus(linked: false);
    return LineLinkStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> createLineLinkCode() async {
    final response = await http.post(Uri.parse('$baseUrl/line/link'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('產生綁定碼失敗');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['code'] as String;
  }

  Future<void> unlinkLine() async {
    await http.delete(Uri.parse('$baseUrl/line/link'), headers: await _authHeaders());
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Future<List<AppCard>> fetchCards() async {
    final response = await http.get(Uri.parse('$baseUrl/cards'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('載入卡片失敗');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => AppCard.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<AppCard> updateCard(
    int id, {
    required String name,
    required String type,
    required String color,
    String? bank,
    String? lastFour,
    double? balance,
    String? paymentDueDate,
    String? passExpiryDate,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/cards/$id'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        'type': type,
        'color': color,
        'bank': bank,
        'last_four': lastFour,
        'balance': balance,
        'payment_due_date': paymentDueDate,
        'pass_expiry_date': passExpiryDate,
      }),
    );
    if (response.statusCode != 200) throw Exception('更新卡片失敗');
    return AppCard.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteCard(int cardId) async {
    final response = await http.delete(Uri.parse('$baseUrl/cards/$cardId'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('刪除卡片失敗');
  }

  // ── Income ────────────────────────────────────────────────────────────────

  Future<List<Income>> fetchIncomes() async {
    final response = await http.get(Uri.parse('$baseUrl/income'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('Failed to load income: ${response.statusCode}');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Income.fromJson(json)).toList();
  }

  Future<void> createIncome({
    int? jobId,
    required String month,
    required double grossAmount,
    double deductionAmount = 0,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/income'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'job_id': jobId,
        'month': month,
        'gross_amount': grossAmount,
        'deduction_amount': deductionAmount,
        'note': note,
      }),
    );
    if (response.statusCode != 200) throw Exception('新增收入失敗');
  }

  Future<void> deleteIncome(int incomeId) async {
    final response = await http.delete(Uri.parse('$baseUrl/income/$incomeId'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('刪除收入失敗');
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<Transaction>> fetchTransactions({int? cardId}) async {
    final uri = Uri.parse('$baseUrl/transactions').replace(
      queryParameters: cardId != null ? {'card_id': '$cardId'} : null,
    );
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('載入交易記錄失敗');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Transaction.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Transaction> createTransaction({
    int? cardId,
    required double amount,
    required String description,
    required String transactionType,
    String? category,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'card_id': cardId,
        'amount': amount,
        'description': description,
        'transaction_type': transactionType,
        'category': category,
        'note': note,
      }),
    );
    if (response.statusCode != 200) throw Exception('新增交易失敗');
    return Transaction.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(int transactionId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/transactions/$transactionId'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('刪除交易失敗');
  }

  Future<AppCard> updateCardBalance(int cardId, double balance) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/cards/$cardId/balance'),
      headers: await _authHeaders(),
      body: jsonEncode({'balance': balance}),
    );
    if (response.statusCode != 200) throw Exception('更新餘額失敗');
    return AppCard.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── Friends ───────────────────────────────────────────────────────────────

  Future<List<Friendship>> fetchFriendships() async {
    final response = await http.get(Uri.parse('$baseUrl/friends'), headers: await _authHeaders());
    if (response.statusCode != 200) throw Exception('Failed to load friends: ${response.statusCode}');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Friendship.fromJson(json)).toList();
  }

  Future<void> requestFriend(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/friends/request'),
      headers: await _authHeaders(),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? '加好友失敗');
    }
  }

  Future<void> acceptFriend(int friendshipId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/friends/$friendshipId/accept'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) throw Exception('接受好友邀請失敗');
  }
}
