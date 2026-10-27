import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// The camera could not be used: no camera, or no permission.
class CameraUnavailable implements Exception {
  const CameraUnavailable([this.reason = '']);

  /// What went wrong, for logs.
  final String reason;

  @override
  String toString() => 'CameraUnavailable($reason)';
}

/// Takes the photo of a street cat. Tests replace it with [FakePhotoService].
abstract class PhotoService {
  /// Opens the camera and returns the path of the saved photo, or null when
  /// the player backed out. Throws [CameraUnavailable] when there is no camera.
  Future<String?> takeStreetCatPhoto(String catId);
}

/// The shared photo service.
final photoServiceProvider = Provider<PhotoService>(
  (ref) => CameraPhotoService(),
);

/// Uses the phone's camera, and keeps the photo in the app's own folder. It
/// is never uploaded.
class CameraPhotoService implements PhotoService {
  @override
  Future<String?> takeStreetCatPhoto(String catId) async {
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 80,
      );
    } catch (e) {
      throw CameraUnavailable('$e');
    }
    if (shot == null) return null;
    final folder = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/street_cats',
    );
    await folder.create(recursive: true);
    final target =
        '${folder.path}/$catId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(shot.path).copy(target);
    return target;
  }
}

/// A scripted camera for tests.
class FakePhotoService implements PhotoService {
  FakePhotoService({
    this.result = '/photos/shot.jpg',
    this.unavailable = false,
  });

  /// The path each call returns. Null means the player backed out.
  String? result;

  /// Makes every call throw [CameraUnavailable].
  bool unavailable;

  /// The cats photographed so far, in order.
  final List<String> asked = [];

  @override
  Future<String?> takeStreetCatPhoto(String catId) async {
    asked.add(catId);
    if (unavailable) throw const CameraUnavailable('no camera');
    final path = result;
    return path == null ? null : '$path#${asked.length}';
  }
}
