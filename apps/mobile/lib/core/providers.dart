import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';

/// Default API base URL. Android emulator reaches the host machine via 10.0.2.2.
/// Override at build time: flutter build apk --dart-define=API_BASE_URL=https://api.gamyamobility.com/api/v1
const String kDefaultApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api/v1');

final authStoreProvider = Provider<AuthStore>((_) => throw UnimplementedError());

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

/// Role chosen on the welcome screen before login/registration.
final roleProvider = StateProvider<String>((_) => 'DRIVER');

extension ApiErr on Object { String get msg => this is ApiException ? (this as ApiException).message : kDebugMode ? toString() : 'Something went wrong'; }

/// Refreshes the session user from /auth/me (e.g. after approval).
Future<AuthUser?> refreshSession(WidgetRef ref) async {
  try {
    final api = ref.read(apiProvider);
    final r = await api.get('/auth/me');
    final u = AuthUser.fromJson(api.data(r)['user'] as Map<String, dynamic>);
    await ref.read(sessionProvider.notifier).update(u);
    return u;
  } catch (_) { return ref.read(sessionProvider); }
}
