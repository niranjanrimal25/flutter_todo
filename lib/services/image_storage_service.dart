import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Copies picked images out of image_picker's temporary cache into a stable
/// app-owned directory so task attachments survive restarts and cache cleanup.
class ImageStorageService {
  static const String _directoryName = 'todo_images';

  static Future<Directory> _imageDirectory({bool create = true}) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<String> storePickedImage(
    String sourcePath, {
    int? todoId,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('The selected image is no longer available.');
    }

    final directory = await _imageDirectory();
    final extension = _safeExtension(sourcePath);
    final id = todoId?.toString() ?? 'draft';
    final fileName =
        'todo_${id}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(path.join(directory.path, fileName));
    final copied = await source.copy(destination.path);
    return copied.path;
  }

  /// Only deletes files inside the app's own attachment directory. This
  /// prevents removing a user's original gallery image if an older task
  /// contains an external path.
  static Future<void> deleteIfOwned(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    final directory = await _imageDirectory(create: false);
    final ownedRoot = path.normalize(path.absolute(directory.path));
    final candidate = path.normalize(path.absolute(imagePath));
    final rootWithSeparator = '$ownedRoot${Platform.pathSeparator}';

    if (!candidate.startsWith(rootWithSeparator)) return;

    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }

  static String _safeExtension(String sourcePath) {
    final extension = path.extension(sourcePath).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
    return allowed.contains(extension) ? extension : '.jpg';
  }
}
