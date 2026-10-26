import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Flutter only adds INTERNET to the debug and profile manifests. Without it
  // in the main one, a release build has no map tiles, no sign-in and no friends.
  test('the release manifest may use the internet and find the user', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final permission in [
      'android.permission.INTERNET',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.POST_NOTIFICATIONS',
    ]) {
      expect(manifest, contains(permission));
    }
  });
}
