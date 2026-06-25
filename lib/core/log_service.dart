import 'dart:io';
import 'dart:async';

import 'package:logger/logger.dart' as lgr;
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });
}

class LogService {
  static final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();
  static Stream<LogEntry> get stream => _controller.stream;

  static lgr.Logger? _fileLogger;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/bili_novel.log');
    if (await file.exists()) {
      await file.delete();
    }

    _fileLogger = lgr.Logger(
      printer: lgr.PrettyPrinter(
        colors: false,
        methodCount: 1,
        dateTimeFormat: lgr.DateTimeFormat.dateAndTime,
        printEmojis: false,
      ),
      output: lgr.FileOutput(file: file),
      filter: lgr.ProductionFilter(),
    );
  }

  static void i(String msg) {
    _fileLogger?.i(msg);
    _controller.add(LogEntry(
      level: LogLevel.info,
      message: msg,
      timestamp: DateTime.now(),
    ));
  }

  static void w(String msg) {
    _fileLogger?.w(msg);
    _controller.add(LogEntry(
      level: LogLevel.warning,
      message: msg,
      timestamp: DateTime.now(),
    ));
  }

  static void e(String msg, {Object? error, StackTrace? stackTrace}) {
    _fileLogger?.e(msg, error: error, stackTrace: stackTrace);
    _controller.add(LogEntry(
      level: LogLevel.error,
      message: msg,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    ));
  }

  static void dispose() {
    _controller.close();
  }
}
