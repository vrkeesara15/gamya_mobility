import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AuthStore();
  await store.load();
  runApp(ProviderScope(overrides: [authStoreProvider.overrideWithValue(store)], child: const GamyaAdminApp()));
}
