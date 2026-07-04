import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

// ── AuthNotifier ──────────────────────────────────────────────────────────
//
// Single source of truth for the current user.
// AsyncData(user)  → logged in
// AsyncData(null)  → logged out
// AsyncLoading     → initial read from SharedPreferences (or in-flight request)
// AsyncError       → login / register request failed
class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() => AuthService().currentUser();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => AuthService().login(email: email, password: password),
    );
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => AuthService().loginWithGoogle());
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => AuthService().register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> logout() async {
    await AuthService().logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);
