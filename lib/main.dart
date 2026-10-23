import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'services/storage/local_store_provider.dart';

/// App entry point. Starts Firebase, opens local storage, then runs the app.
/// The opened store is handed to Riverpod so every provider can read saved data
/// without waiting for it.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = await openLocalStore();
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const CatwalkApp(),
    ),
  );
}
