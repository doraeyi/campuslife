import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../services/api_client.dart';

/// Raw count of roster photos waiting on the user's review (see the
/// "班表匯入" page), mirrors [bank_notify_pending_provider]'s shape.
class RosterPendingCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final pending = await ApiClient().fetchPendingRosterPhotos();
    return pending.length;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pending = await ApiClient().fetchPendingRosterPhotos();
      return pending.length;
    });
  }
}

final rosterPendingCountProvider =
    AsyncNotifierProvider<RosterPendingCountNotifier, int>(
        RosterPendingCountNotifier.new);
