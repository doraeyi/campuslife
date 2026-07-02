import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/card_model.dart';
import '../../../models/job.dart';
import '../../../models/settings_models.dart';
import '../../../services/api_client.dart';

// ── UserProfile Provider ──────────────────────────────────────────────────

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ApiClient().fetchMe();

  Future<void> updateProfile({String? name, String? picture}) async {
    final updated = await ApiClient().updateMe(name: name, picture: picture);
    state = AsyncData(updated);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

// ── Google Link Provider ──────────────────────────────────────────────────

class GoogleLinkNotifier extends AsyncNotifier<GoogleLinkStatus> {
  @override
  Future<GoogleLinkStatus> build() => ApiClient().fetchGoogleLink();

  Future<void> unlink() async {
    await ApiClient().unlinkGoogle();
    state = const AsyncData(GoogleLinkStatus(linked: false));
  }
}

final googleLinkProvider = AsyncNotifierProvider<GoogleLinkNotifier, GoogleLinkStatus>(
  GoogleLinkNotifier.new,
);

// ── LINE Link Provider ────────────────────────────────────────────────────

class LineLinkNotifier extends AsyncNotifier<LineLinkStatus> {
  @override
  Future<LineLinkStatus> build() => ApiClient().fetchLineLink();

  Future<void> checkLink() async {
    final status = await ApiClient().fetchLineLink();
    if (status.linked) state = AsyncData(status);
  }

  Future<void> unlink() async {
    await ApiClient().unlinkLine();
    state = const AsyncData(LineLinkStatus(linked: false));
  }
}

final lineLinkProvider = AsyncNotifierProvider<LineLinkNotifier, LineLinkStatus>(
  LineLinkNotifier.new,
);

// ── Cards Provider ────────────────────────────────────────────────────────

class CardsNotifier extends AsyncNotifier<List<AppCard>> {
  @override
  Future<List<AppCard>> build() => ApiClient().fetchCards();

  Future<AppCard> addCard({
    required String name,
    required String type,
    required String color,
    String? bank,
    String? lastFour,
    double? balance,
  }) async {
    final card = await ApiClient().createCard(
      name: name, type: type, color: color,
      bank: bank, lastFour: lastFour, balance: balance,
    );
    state = state.whenData((list) => [...list, card]);
    return card;
  }

  Future<void> updateCard(int id, {
    required String name,
    required String type,
    required String color,
    String? bank,
    String? lastFour,
    double? balance,
  }) async {
    final card = await ApiClient().updateCard(
      id, name: name, type: type, color: color,
      bank: bank, lastFour: lastFour, balance: balance,
    );
    state = state.whenData((list) => list.map((c) => c.id == id ? card : c).toList());
  }

  Future<void> deleteCard(int id) async {
    await ApiClient().deleteCard(id);
    state = state.whenData((list) => list.where((c) => c.id != id).toList());
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<AppCard>>(
  CardsNotifier.new,
);

// ── Jobs Provider ─────────────────────────────────────────────────────────

class SettingsJobsNotifier extends AsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() => ApiClient().fetchJobs();

  Future<void> addJob({
    required String name,
    required String colorHex,
    required PayType payType,
    double? rate,
    int? payday,
    double laborInsuranceFee = 0,
    double healthInsuranceFee = 0,
  }) async {
    final job = await ApiClient().createJob(
      name: name,
      colorHex: colorHex,
      payType: payType,
      hourlyRate: payType == PayType.hourly ? rate : null,
      monthlySalary: payType == PayType.monthly ? rate : null,
      payday: payday,
      laborInsuranceFee: laborInsuranceFee,
      healthInsuranceFee: healthInsuranceFee,
    );
    state = state.whenData((list) => [...list, job]);
  }

  Future<void> updateJob({
    required int id,
    required String name,
    required String colorHex,
    required PayType payType,
    double? rate,
    int? payday,
    double laborInsuranceFee = 0,
    double healthInsuranceFee = 0,
  }) async {
    final updated = await ApiClient().updateJob(
      id,
      name: name,
      colorHex: colorHex,
      payType: payType,
      hourlyRate: payType == PayType.hourly ? rate : null,
      monthlySalary: payType == PayType.monthly ? rate : null,
      payday: payday,
      laborInsuranceFee: laborInsuranceFee,
      healthInsuranceFee: healthInsuranceFee,
    );
    state = state.whenData((list) => list.map((j) => j.id == id ? updated : j).toList());
  }

  Future<void> deleteJob(int id) async {
    await ApiClient().deleteJob(id);
    state = state.whenData((list) => list.where((j) => j.id != id).toList());
  }
}

final settingsJobsProvider = AsyncNotifierProvider<SettingsJobsNotifier, List<Job>>(
  SettingsJobsNotifier.new,
);

// ── Budget Provider ───────────────────────────────────────────────────────

class BudgetNotifier extends AsyncNotifier<double?> {
  static const _key = 'yiwallet_budget';

  @override
  Future<double?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key);
  }

  Future<void> save(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, amount);
    state = AsyncData(amount);
  }
}

final budgetProvider = AsyncNotifierProvider<BudgetNotifier, double?>(
  BudgetNotifier.new,
);

// ── Has-Password Provider ─────────────────────────────────────────────────

final hasPasswordProvider = FutureProvider<bool>((ref) => ApiClient().fetchHasPassword());

// ── PackageInfo Provider ──────────────────────────────────────────────────

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
