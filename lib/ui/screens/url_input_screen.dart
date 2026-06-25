import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bili_novel_packer/core/novel_packer.dart';
import 'package:bili_novel_packer/ui/providers/novel_provider.dart';

class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  State<UrlInputScreen> createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String text) {
    final trimmed = text.trim();
    final valid = trimmed.isNotEmpty &&
        (NovelPacker.sources.any((s) => s.supportUrl(trimmed)));
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  Future<void> _submit() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;

    final provider = context.read<NovelProvider>();
    await provider.loadNovel(url);

    if (!mounted) return;
    if (provider.state is NovelLoaded) {
      context.push('/catalog');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovelProvider>();
    final isLoading = provider.state is NovelLoading;
    final error = switch (provider.state) {
      NovelError(:final message) => message,
      _ => null,
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('轻小说打包器'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.push('/settings'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '轻小说打包器',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将网络轻小说打包成 EPUB 格式',
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    onChanged: _validate,
                    enabled: !isLoading,
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: '粘贴小说链接',
                      prefixIcon: Icon(Icons.link_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      errorText: error,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(context, '哔哩轻小说', Icons.language_rounded),
                      _buildTag(context, '轻小说文库', Icons.library_books_rounded),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: (_isValid && !isLoading) ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isValid ? colorScheme.primary : colorScheme.surfaceContainerHigh,
                    foregroundColor: _isValid ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    disabledBackgroundColor: colorScheme.surfaceContainerHigh,
                    disabledForegroundColor: colorScheme.onSurfaceVariant,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.onPrimary),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.download_rounded, size: 20), SizedBox(width: 8), Text('开始加载')],
                        ),
                ),
              ),
              const Spacer(flex: 3),
              Text(
                'v0.2.45',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
