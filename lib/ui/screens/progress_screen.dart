import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:bili_novel_packer/core/log_service.dart';
import 'package:bili_novel_packer/core/saf_helper.dart';
import 'package:bili_novel_packer/ui/providers/novel_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _logController = ScrollController();
  final List<LogEntry> _logs = [];
  StreamSubscription<LogEntry>? _subscription;
  DateTime? _startTime;
  Timer? _timer;
  bool _scrollPending = false;

  static const int _maxLogEntries = 500;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _subscription = LogService.stream.listen((entry) {
      if (!mounted) return;
      setState(() {
        _logs.add(entry);
        while (_logs.length > _maxLogEntries) {
          _logs.removeAt(0);
        }
      });
      if (!_scrollPending) {
        _scrollPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollPending = false;
          _scrollToBottom();
        });
      }
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = context.read<PackProvider>().state;
      if (state is PackCompleted || state is PackFailed) {
        _timer?.cancel();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _logController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logController.hasClients) {
      _logController.animateTo(
        _logController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatDuration(Duration d) {
    final secs = d.inSeconds;
    if (secs < 60) return '$secs秒';
    return '${d.inMinutes}分 ${secs % 60}秒';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatSpeed(double speed) {
    if (speed <= 0) return '';
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final packProvider = context.watch<PackProvider>();
    final state = packProvider.state;
    final colorScheme = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(_startTime!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('打包进度'),
        automaticallyImplyLeading: state is PackCompleted || state is PackFailed,
        actions: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          )),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildProgressContent(state, elapsed, colorScheme),
              ),
            ),
          ),
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    '实时日志',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_logs.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _logs.isEmpty
                      ? Center(
                          child: Text(
                            '等待日志...',
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                        )
                      : ListView.builder(
                          controller: _logController,
                          padding: const EdgeInsets.all(14),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final entry = _logs[index];
                            final time =
                                '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                                '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                                '${entry.timestamp.second.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLogBadge(entry.level, colorScheme),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '$time  ',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          TextSpan(
                                            text: entry.message,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: entry.level == LogLevel.error
                                                  ? const Color(0xFFE53935)
                                                  : colorScheme.onSurface,
                                              fontFamily: 'monospace',
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ] else
            const Expanded(child: SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _buildActions(state, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildLogBadge(LogLevel level, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final (bg, label, fg) = switch (level) {
      LogLevel.error => (
          isDark ? const Color(0xFF4E1515) : const Color(0xFFFFEBEE),
          'ERR',
          isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
        ),
      LogLevel.warning => (
          isDark ? const Color(0xFF4E3015) : const Color(0xFFFFF3E0),
          'WRN',
          isDark ? const Color(0xFFFFCC80) : const Color(0xFFE65100),
        ),
      LogLevel.info => (
          colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.5),
          'INF',
          colorScheme.primary,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildProgressContent(PackState state, Duration elapsed, ColorScheme colorScheme) {
    return switch (state) {
      PackIdle() => const Text('准备就绪'),
      PackingProgress(:final progress, :final currentOperation, :final totalBytes, :final speed, :final coverData) => Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 64,
                child: coverData != null
                    ? Image.memory(coverData, fit: BoxFit.cover)
                    : Container(color: colorScheme.surfaceContainerHigh,
                        child: const Icon(Icons.auto_stories_rounded, size: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(currentOperation,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null, minHeight: 4,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    totalBytes > 0
                        ? '已下载 ${_formatFileSize(totalBytes)} · ${_formatSpeed(speed)} · ${_formatDuration(elapsed)}'
                        : '已耗时 ${_formatDuration(elapsed)}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      PackCompleted(:final fileName, :final fileSize, :final coverData) => Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 64,
                child: coverData != null
                    ? Image.memory(coverData, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('打包完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(fileSize > 0 ? '${_formatFileSize(fileSize)} · ${_formatDuration(elapsed)}' : _formatDuration(elapsed),
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  Text(fileName, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      PackFailed(:final message) => Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC62828),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFC62828),
                ),
              ),
            ),
          ],
        ),
    };
  }

  Widget _buildActions(PackState state, ColorScheme colorScheme) {
    if (state is PackCompleted) {
      return _buildCompletedActions(state, colorScheme);
    }
    if (state is PackFailed) {
      return _buildFailedActions(context, colorScheme);
    }
    return const SizedBox.shrink();
  }

  Widget _buildCompletedActions(PackCompleted state, ColorScheme colorScheme) {
    final openPath = state.fileUri.isNotEmpty ? state.fileUri : p.join(state.outputPath, state.fileName);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => SafHelper.openFile(openPath),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: const Text('打开阅读'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => SafHelper.shareFile(openPath),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('分享'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedActions(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text('重试'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC62828),
            side: const BorderSide(color: Color(0xFFEF9A9A)),
          ),
        ),
      ),
    );
  }
}
