import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';

// Google Cloud Console 的 Web application Client ID，
// 必須跟後端 .env 的 GOOGLE_CLIENT_ID 相同。
const _webGoogleClientId =
    '942135242848-6oopfsvn16n5do658oond8sathsoiae8.apps.googleusercontent.com';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  // Web 平台一定要顯式帶 clientId（沒有原生 App 殼可以幫忙找設定）；
  // Android/iOS 則靠 serverClientId 取得跟後端 GOOGLE_CLIENT_ID 一致的 idToken，
  // iOS 另外還需要 Info.plist 的 GIDClientID / URL scheme 設定。
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _webGoogleClientId : null,
    serverClientId: kIsWeb ? null : _webGoogleClientId,
  );

  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return AppUser.fromJson(jsonDecode(json));
  }

  Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'display_name': displayName}),
    );
    return _handleAuthResponse(response);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuthResponse(response);
  }

  Future<AppUser> loginWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('已取消 Google 登入');
    }

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    // Flutter Web 的 signIn() 走的是瀏覽器 OAuth2 授權流程，通常只會拿到
    // accessToken、拿不到 idToken；原生 Android/iOS 才會有 idToken。
    // 後端兩種都支援驗證，這裡哪個有值就送哪個。
    if (idToken == null && accessToken == null) {
      throw Exception('無法取得 Google 驗證資訊');
    }

    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (idToken != null) 'id_token': idToken,
        if (accessToken != null) 'access_token': accessToken,
      }),
    );
    return _handleAuthResponse(response);
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<AppUser> _handleAuthResponse(http.Response response) async {
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? '驗證失敗');
    }
    final data = jsonDecode(response.body);
    final user = AppUser.fromJson(data['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['access_token']);
    await prefs.setString(_userKey, jsonEncode(data['user']));

    return user;
  }
}
