import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bili_novel_packer/light_novel/base/light_novel_model.dart';
import 'package:bili_novel_packer/ui/providers/novel_provider.dart';
import 'package:bili_novel_packer/ui/providers/settings_provider.dart';
import 'package:bili_novel_packer/ui/widgets/bottom_action_bar.dart';

class _AppBarAction extends StatelessWidget {
  const _AppBarAction();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_rounded),
      onPressed: () => context.push('/settings'),
    );
  }
}class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovelProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(title: const Text('小说详情'), actions: const [_AppBarAction()]),
      body: switch (state) {
        NovelLoading() => const Center(child: CircularProgressIndicator()),
        NovelError(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ),
        NovelLoaded(
          :final novel,
          :final catalog,
          :final selectedVolume,
        ) =>
          _buildContent(context, provider, novel, catalog, selectedVolume),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    NovelProvider provider,
    Novel novel,
    Catalog catalog,
    Volume? selectedVolume,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        novel.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      if (novel.alias != null && novel.alias!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            novel.alias!,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            novel.author,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              novel.status,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (novel.tags != null && novel.tags!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            novel.tags!.join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      if (novel.description != null && novel.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            novel.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '选择分卷',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${catalog.volumes.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...catalog.volumes.map(
                (volume) => _VolumeCard(
                  volume: volume,
                  isSelected: selectedVolume == volume,
                  onTap: () => provider.selectVolume(volume),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        BottomActionBar(
          child: FilledButton(
            onPressed: selectedVolume == null
                ? null
                : () {
                      final pp = context.read<PackProvider>();
                      final sp = context.read<SettingsProvider>();
                      pp.startPacking(
                        packer: provider.packer,
                        volumes: [selectedVolume],
                        addChapterTitle: pp.addChapterTitle,
                        outputDirectory: sp.outputDirectory,
                        useNumericId: sp.useNumericId,
                      );
                      context.push('/progress');
                    },
            child: Text(
              selectedVolume != null
                  ? '打包 ${selectedVolume.volumeName.isNotEmpty ? selectedVolume.volumeName : ""}'
                  : '请选择分卷',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumeCard extends StatefulWidget {
  final Volume volume;
  final bool isSelected;
  final VoidCallback onTap;

  const _VolumeCard({
    required this.volume,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_VolumeCard> createState() => _VolumeCardState();
}

class _VolumeCardState extends State<_VolumeCard> {
  Uint8List? _coverData;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  void _loadCover() {
    final url = widget.volume.cover;
    if (url == null || url.isEmpty) return;

    final provider = context.read<NovelProvider>();
    final cached = provider.getCachedCover(url);
    if (cached != null) {
      _coverData = cached;
      return;
    }
    if (!provider.isCoverLoading(url)) {
      provider.preloadCover(url).then((_) {
        if (mounted) {
          setState(() {
            _coverData = provider.getCachedCover(url);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showCover = _coverData != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: widget.isSelected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: widget.isSelected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: showCover
                        ? Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(1, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  Image.memory(
                                    _coverData!,
                                    width: 48,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            color: widget.isSelected
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerHigh,
                            child: Icon(
                              widget.isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.auto_stories_rounded,
                              size: 24,
                              color: widget.isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.volume.volumeName.isNotEmpty
                            ? widget.volume.volumeName
                            : widget.volume.catalog.novel.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: widget.isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
