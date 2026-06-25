import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bili_novel_packer/app.dart';
import 'package:bili_novel_packer/core/log_service.dart';
import 'package:bili_novel_packer/ui/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init();

  final settings = SettingsProvider();
  await settings.init();

  runZonedGuarded(() {
    ErrorWidget.builder = (details) {
      LogService.e('Widget 渲染异常', error: details.exception, stackTrace: details.stack);
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFE53935)),
                  const SizedBox(height: 16),
                  const Text('出现错误', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(details.exception.toString(), style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    };

    runApp(BiliNovelPackerApp(settings: settings));
  }, (Object error, StackTrace stack) {
    LogService.e('未捕获的异常', error: error, stackTrace: stack);
  });
}
