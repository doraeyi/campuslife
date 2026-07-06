import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../bank_notify_auto_processor.dart';

/// Number of bank-notify screenshots still waiting on manual review, after
/// auto-processing everything that could be parsed automatically. Watched by
/// the home page's bell icon; first watch (e.g. right after login) is what
/// triggers the "check on app open" pass described in the plan.
class BankNotifyPendingCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => BankNotifyAutoProcessor().processAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => BankNotifyAutoProcessor().processAll());
  }
}

final bankNotifyPendingCountProvider =
    AsyncNotifierProvider<BankNotifyPendingCountNotifier, int>(BankNotifyPendingCountNotifier.new);
