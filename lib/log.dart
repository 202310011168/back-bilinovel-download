import 'package:bili_novel_packer/core/log_service.dart' as core;

/// 兼容: light_novel 源文件引用此常量用于错误提示
const String logFilePath = "bili_novel.log";

/// 兼容层: light_novel 源文件通过 `logger.i(...)` 调用
/// 实际委托给 LogService (文件 + Stream 双输出)
class LoggerProxy {
  void i(String msg) => core.LogService.i(msg);
  void w(String msg) => core.LogService.w(msg);

  /// 兼容原始 Logger.e 接受任意类型第一个参数
  void e(Object msg, {Object? error, StackTrace? stackTrace}) =>
      core.LogService.e(msg.toString(), error: error, stackTrace: stackTrace);
}

final LoggerProxy logger = LoggerProxy();
