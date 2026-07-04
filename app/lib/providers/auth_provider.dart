import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/settings/providers/settings_provider.dart';
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

  // 這些 provider 都是抓「目前登入者」的資料（個人資料、job、卡片、Google/LINE
  // 綁定狀態…），本身不是 autoDispose，也不會知道使用者換人了。如果登入/登出後
  // 不主動 invalidate，Riverpod 會一直沿用「前一個使用者」快取的結果，
  // 就會出現 A 登入卻看到 B 的設定資料這種帳號資料外洩的情況。
  void _invalidateUserScopedProviders() {
    ref.invalidate(userProfileProvider);
    ref.invalidate(googleLinkProvider);
    ref.invalidate(lineLinkProvider);
    ref.invalidate(cardsProvider);
    ref.invalidate(settingsJobsProvider);
    ref.invalidate(hasPasswordProvider);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => AuthService().login(email: email, password: password),
    );
    _invalidateUserScopedProviders();
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => AuthService().loginWithGoogle());
    _invalidateUserScopedProviders();
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
    _invalidateUserScopedProviders();
  }

  Future<void> logout() async {
    await AuthService().logout();
    state = const AsyncData(null);
    _invalidateUserScopedProviders();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);
