import 'package:flutter/services.dart';

class SafHelper {
  static const _channel = MethodChannel('bilinovel/saf');

  /// Initialize Download/bilinovel directory via MediaStore.
  static Future<String> initBilinovelDir() async {
    final path = await _channel.invokeMethod<String>('initBilinovelDir');
    return path ?? 'Download/bilinovel';
  }

  /// Save EPUB bytes to Download/bilinovel/[subfolder]/ via MediaStore.
  /// Returns the content:// URI string for the saved file, or empty on failure.
  static Future<String> saveToBilinovel(String fileName, List<int> data, {String subfolder = ''}) async {
    final uri = await _channel.invokeMethod<String>('saveToBilinovel', {
      'fileName': fileName,
      'data': data,
      'subfolder': subfolder,
    });
    return uri ?? '';
  }

  /// Open EPUB file with system chooser (ACTION_VIEW intent).
  static Future<void> openFile(String uri) async {
    await _channel.invokeMethod('openFile', {'uri': uri});
  }

  /// Share EPUB file via system share sheet (ACTION_SEND intent).
  static Future<void> shareFile(String uri) async {
    await _channel.invokeMethod('shareFile', {'uri': uri});
  }
}
