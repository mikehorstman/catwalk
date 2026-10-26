import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('/Users/mikehorstman/.hermes/cache/scratch/$name.png');
    await file.writeAsBytes(bytes);
    return true;
  },
);
