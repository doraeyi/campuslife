import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../services/api_client.dart';
import '../bank_notify_auto_processor.dart';

/// Number of bank-notify screenshots still waiting on manual review. Watched
/// by the home page's bell icon; first watch (e.g. right after login) is
/// what triggers the "check on app open" pass described in the plan.
///
/// Shows the raw pending count immediately (so the badge appears the moment
/// the page loads, not after however long OCR takes to run), then updates
/// down to whatever's left once auto-processing finishes.
class BankNotifyPendingCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final raw = await ApiClient().fetchPendingScreenshots();
    state = AsyncData(raw.length);
    if (raw.isEmpty) return 0;
    return BankNotifyAutoProcessor().processAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final raw = await ApiClient().fetchPendingScreenshots();
      state = AsyncData(raw.length);
      if (raw.isEmpty) return 0;
      return BankNotifyAutoProcessor().processAll();
    });
  }
}

final bankNotifyPendingCountProvider =
    AsyncNotifierProvider<BankNotifyPendingCountNotifier, int>(
        BankNotifyPendingCountNotifier.new);
