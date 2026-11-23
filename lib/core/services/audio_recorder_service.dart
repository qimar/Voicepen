import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<String> startRecording() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docsDir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final filename = 'memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = p.join(audioDir.path, filename);
    _currentRecordingPath = filePath;

    // Voice-optimized mono 32kbps AAC-LC recording.
    // Keeps a 1-hour recording under ~14.4 MB (well within 25 MB cloud limits).
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 32000,
      bitRate: 32000,
      numChannels: 1,
    );

    await _audioRecorder.start(config, path: filePath);
    return filePath;
  }

  Future<void> pauseRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.pause();
    }
  }

  Future<void> resumeRecording() async {
    if (await _audioRecorder.isPaused()) {
      await _audioRecorder.resume();
    }
  }

  Future<String?> stopRecording() async {
    try {
      // If paused, native recorder may fail on stop without resuming first
      if (await _audioRecorder.isPaused()) {
        try {
          await _audioRecorder.resume();
        } catch (_) {}
      }
      final path = await _audioRecorder.stop();
      final recordedPath = path ?? _currentRecordingPath;
      _currentRecordingPath = null;
      return recordedPath;
    } catch (e) {
      final fallbackPath = _currentRecordingPath;
      _currentRecordingPath = null;
      return fallbackPath;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
  }

  Stream<Amplitude> get amplitudeStream =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  Future<bool> isPaused() async {
    return await _audioRecorder.isPaused();
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
