import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../services/api_client.dart';

/// Raw count of bank-notify screenshots waiting on the user's review (see
/// the "銀行通知記帳" page). Watched by the home page's bell icon.
///
/// This used to also trigger a silent OCR-and-auto-record pass, but that
/// made failures invisible -- if anything went wrong the badge just quietly
/// stayed wrong with no way to tell why. Now it's just a count; OCR and
/// recording only happen when the user opens the review page and explicitly
/// taps "一鍵入帳" on something.
class BankNotifyPendingCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final pending = await ApiClient().fetchPendingScreenshots();
    return pending.length;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pending = await ApiClient().fetchPendingScreenshots();
      return pending.length;
    });
  }
}

final bankNotifyPendingCountProvider =
    AsyncNotifierProvider<BankNotifyPendingCountNotifier, int>(
        BankNotifyPendingCountNotifier.new);
