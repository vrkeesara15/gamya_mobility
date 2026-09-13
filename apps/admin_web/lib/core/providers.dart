import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';

const String kDefaultApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/v1');

final authStoreProvider = Provider<AuthStore>((_) => throw UnimplementedError());

/// Session state: current user or null.
class SessionNotifier extends StateNotifier<AuthUser?> {
  SessionNotifier(this._store) : super(_store.user);
  final AuthStore _store;
  Future<void> login(String token, AuthUser user) async { await _store.save(token, user); state = user; }
  Future<void> update(AuthUser user) async { await _store.updateUser(user); state = user; }
  Future<void> logout() async { await _store.clear(); state = null; }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AuthUser?>((ref) => SessionNotifier(ref.watch(authStoreProvider)));

final apiProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(authStoreProvider);
  return ApiClient(baseUrl: kDefaultApiBaseUrl, auth: store, onUnauthorized: () => ref.read(sessionProvider.notifier).logout());
});

/// Sidebar badge counts + unread notifications; refreshed by the shell.
class Badges { const Badges({this.pendingApprovals = 0, this.unread = 0}); final int pendingApprovals; final int unread; }
final badgesProvider = StateProvider<Badges>((_) => const Badges());

/// Global "something changed – reload" tick used by list pages after mutations from dialogs.
final refreshTickProvider = StateProvider<int>((_) => 0);

extension ApiErr on Object { String get msg => this is ApiException ? (this as ApiException).message : kDebugMode ? toString() : 'Something went wrong'; }
