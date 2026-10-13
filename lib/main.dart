import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/storage/local_store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await openLocalStore();
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const CatwalkApp(),
    ),
  );
}
