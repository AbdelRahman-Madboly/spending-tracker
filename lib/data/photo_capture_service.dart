import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'photo_storage.dart';

/// What came back from a camera/gallery attempt.
enum PhotoCaptureOutcome {
  /// A photo was picked (or taken) and copied into app storage.
  attached,

  /// The user backed out of the camera/gallery UI without picking anything.
  /// Not an error — nothing should be shown for this.
  cancelled,

  /// The relevant OS permission (camera) was denied. The caller should
  /// show the user a plain message; never crash, never fail silently.
  permissionDenied,
}

class PhotoCaptureResult {
  final PhotoCaptureOutcome outcome;

  /// Set only when [outcome] is [PhotoCaptureOutcome.attached] — the path
  /// to store on the entry, relative to the app's documents directory.
  final String? relativePath;

  const PhotoCaptureResult(this.outcome, [this.relativePath]);
}

/// Everything `AddSheet` needs to attach a photo, behind one seam.
///
/// image_picker and permission_handler both talk to platform channels that
/// don't run under `flutter test`, so widget tests inject a fake
/// implementation of this interface instead of exercising the real one —
/// see [PhotoStorage] for the copy/relative-path logic, which IS unit
/// tested directly since it touches only `dart:io`.
abstract class PhotoCaptureService {
  Future<PhotoCaptureResult> captureFromCamera();
  Future<PhotoCaptureResult> pickFromGallery();

  /// Resolves a relative path previously returned in a [PhotoCaptureResult]
  /// back into the absolute file it lives at right now, for display.
  Future<File> resolve(String relativePath);

  /// Deletes a previously attached photo at [relativePath] — used to clean
  /// up a photo that was attached during an add-sheet session but never
  /// ended up in a saved entry (the sheet was dismissed, or the photo was
  /// replaced by a later capture). Safe to call even if the file no longer
  /// exists.
  Future<void> delete(String relativePath);
}

class ImagePickerPhotoCaptureService implements PhotoCaptureService {
  ImagePickerPhotoCaptureService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PhotoCaptureResult> captureFromCamera() async {
    // Requested explicitly (rather than left to image_picker) so a denial
    // is reported back to the caller as PhotoCaptureOutcome.permissionDenied
    // instead of surfacing as a bare null/cancel that looks identical to
    // the user simply backing out of the camera.
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      return const PhotoCaptureResult(PhotoCaptureOutcome.permissionDenied);
    }
    final picked = await _picker.pickImage(source: ImageSource.camera);
    return _importIfPicked(picked);
  }

  @override
  Future<PhotoCaptureResult> pickFromGallery() async {
    // No explicit permission request: on the Android versions this app
    // targets, image_picker's gallery source uses the system photo picker,
    // which needs no runtime permission at all.
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    return _importIfPicked(picked);
  }

  Future<PhotoCaptureResult> _importIfPicked(XFile? picked) async {
    if (picked == null) {
      return const PhotoCaptureResult(PhotoCaptureOutcome.cancelled);
    }
    final storage = PhotoStorage(await getApplicationDocumentsDirectory());
    final relativePath = await storage.importPhoto(File(picked.path));
    return PhotoCaptureResult(PhotoCaptureOutcome.attached, relativePath);
  }

  @override
  Future<File> resolve(String relativePath) async {
    final storage = PhotoStorage(await getApplicationDocumentsDirectory());
    return storage.resolve(relativePath);
  }

  @override
  Future<void> delete(String relativePath) async {
    final storage = PhotoStorage(await getApplicationDocumentsDirectory());
    await storage.delete(relativePath);
  }
}
