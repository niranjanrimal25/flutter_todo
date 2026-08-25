import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/alarm_tone.dart';
import 'storage_service.dart';

/// Owns imported alarm audio files and their persisted display names.
class ToneStorageService {
  static const String _stateKey = 'custom_alarm_tones';
  static const String _directoryName = 'alarm_tones';

  static Future<Directory> _toneDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<List<AlarmTone>> loadCustomTones() async {
    final raw = await StorageService.getAppState(_stateKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final tones = decoded
          .whereType<Map>()
          .map((item) => AlarmTone.fromMap(Map<String, dynamic>.from(item)))
          .where((tone) => tone.path.isNotEmpty)
          .toList();
      return tones;
    } catch (_) {
      return [];
    }
  }

  /// FilePicker uses Android's Storage Access Framework / iOS Files picker,
  /// so the app receives a user-selected file reference without requesting
  /// broad storage or microphone permission.
  static Future<AlarmTone?> pickAndStoreTone() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final sourcePath = result.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('The selected audio file is no longer available.');
    }

    final directory = await _toneDirectory();
    final extension = path.extension(sourcePath).toLowerCase();
    final originalName = path.basenameWithoutExtension(sourcePath).trim();
    final label = originalName.isEmpty ? 'Custom tone' : originalName;
    final fileName =
        'tone_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.audio' : extension}';
    final copied = await source.copy(path.join(directory.path, fileName));
    final tone = AlarmTone(label: label, path: copied.path);

    final tones = await loadCustomTones();
    tones.removeWhere((existing) => existing.path == tone.path);
    tones.add(tone);
    await StorageService.saveAppState(
      _stateKey,
      jsonEncode(tones.map((item) => item.toMap()).toList()),
    );
    return tone;
  }
}
