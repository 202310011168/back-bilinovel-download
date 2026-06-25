import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:bili_novel_packer/core/log_service.dart';
import 'package:bili_novel_packer/ui/providers/settings_provider.dart';
import 'package:bili_novel_packer/ui/providers/novel_provider.dart';
import 'package:bili_novel_packer/ui/widgets/color_wheel.dart' as wheel;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _buildSection(context, '输出与打包', [
            _buildSwitchTile(
              context,
              icon: Icons.title_rounded,
              title: '章节标题',
              subtitle: '在每章开头添加章节标题',
              value: context.watch<PackProvider>().addChapterTitle,
              onChanged: (v) => context.read<PackProvider>().setAddChapterTitle(v),
            ),
            _buildSwitchTile(
              context,
              icon: Icons.tag_rounded,
              title: '书籍编号',
              subtitle: settings.useNumericId ? '使用 URL 中的数字 ID' : '使用书名',
              value: settings.useNumericId,
              onChanged: settings.setUseNumericId,
            ),
            _buildFilePickerTile(context, settings),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, '外观与显示', [
            _buildSelectTile(
              context,
              icon: Icons.brightness_6_rounded,
              title: '主题模式',
              subtitle: settings.themeMode == ThemeMode.system
                  ? '跟随系统'
                  : settings.themeMode == ThemeMode.light
                      ? '浅色'
                      : '深色',
              onTap: () => _showThemePicker(context),
            ),
            _buildSwitchTile(
              context,
              icon: Icons.palette_rounded,
              title: '动态取色',
              subtitle: '基于主色生成完整配色方案',
              value: settings.useDynamicColor,
              onChanged: settings.setUseDynamicColor,
            ),
            _buildSelectTile(
              context,
              icon: Icons.color_lens_rounded,
              title: '主题颜色',
              subtitle: _colorName(settings.accentColor),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: settings.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: settings.accentColor.withValues(alpha: 0.3), width: 2),
                ),
              ),
              onTap: () => _showColorPicker(context),
            ),
            _buildSwitchTile(
              context,
              icon: Icons.screen_rotation_rounded,
              title: '异性屏适配',
              subtitle: '开启后预留安全区，避免内容被遮挡',
              value: settings.safeAreaEnabled,
              onChanged: settings.setSafeAreaEnabled,
            ),
            _buildBgSection(context, settings),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSelectTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerTile(BuildContext context, SettingsProvider settings) {
    final cs = Theme.of(context).colorScheme;
    final pp = context.watch<PackProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () async {
          final dir = await FilePicker.platform.getDirectoryPath();
          if (dir != null) {
            try {
              final testFile = File('$dir/.write_test');
              await testFile.writeAsString('');
              await testFile.delete();
              if (!context.mounted) return;
              pp.setOutputDirectory(dir);
              context.read<SettingsProvider>().setOutputDirectory(dir);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('所选目录无写入权限，将使用默认目录'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.folder_rounded, size: 20, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('输出目录', style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      pp.outputDirectory ?? 'Download/bilinovel/书名/',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBgSection(BuildContext context, SettingsProvider settings) {
    final cs = Theme.of(context).colorScheme;
    final fitNames = ['铺满', '平铺', '拉伸'];
    final fitIcons = [Icons.fit_screen_rounded, Icons.grid_view_rounded, Icons.photo_size_select_large_rounded];

    return Column(
      children: [
        const Divider(height: 1, indent: 62),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: InkWell(
            onTap: () => _pickBackgroundImage(context, settings),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    image: settings.backgroundPath != null
                        ? DecorationImage(image: FileImage(File(settings.backgroundPath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: settings.backgroundPath == null
                      ? Icon(Icons.image_outlined, size: 20, color: cs.onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('背景图片', style: TextStyle(fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(settings.backgroundPath != null ? '已设置，点此更换' : '选择一张图片作为背景',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                if (settings.backgroundPath != null)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: cs.error),
                    onPressed: () => settings.setBackgroundPath(null),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
        if (settings.backgroundPath != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(62, 0, 16, 4),
            child: Row(
              children: [
                Text('透明度', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Expanded(child: Slider(
                  value: settings.backgroundOpacity,
                  min: 0.05, max: 1.0,
                  onChanged: settings.setBackgroundOpacity,
                )),
                Text('${(settings.backgroundOpacity * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(62, 0, 16, 4),
            child: Row(
              children: [
                ...List.generate(3, (i) {
                  final selected = settings.backgroundFit == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(fitNames[i], style: const TextStyle(fontSize: 12)),
                      avatar: Icon(fitIcons[i], size: 16),
                      onSelected: (_) => settings.setBackgroundFit(i),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
          _buildSwitchTile(
            context,
            icon: Icons.palette_outlined,
            title: '根据背景取色',
            subtitle: '自动提取主色设为主题色',
            value: settings.extractedColor != null,
            onChanged: (v) => _toggleExtractColor(context, settings, v),
          ),
        ],
      ],
    );
  }

  Future<void> _pickBackgroundImage(BuildContext context, SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dest = '${appDir.path}/bg_image${file.extension != null ? '.${file.extension}' : '.jpg'}';
      await File(file.path!).copy(dest);
      settings.setBackgroundPath(dest);
    } catch (e) {
      settings.setBackgroundPath(file.path);
    }
  }

  Future<void> _toggleExtractColor(BuildContext context, SettingsProvider settings, bool enable) async {
    if (!enable) {
      settings.setExtractedColor(null);
      return;
    }
    final path = settings.backgroundPath;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData();
      if (byteData == null) return;

      final pixels = byteData.buffer.asUint32List();
      final Map<int, int> hueCount = {};
      int maxCount = 0;
      int dominantHue = 0;

      for (final pixel in pixels) {
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;
        final h = HSVColor.fromAHSV(1, r / 255 * 360, g / 255, b / 255).hue.toInt();
        final sat = (g / 255).clamp(0.0, 1.0); // approximate
        if (sat > 0.15) {
          final bucket = (h / 10).floor();
          hueCount[bucket] = (hueCount[bucket] ?? 0) + 1;
          if (hueCount[bucket]! > maxCount) {
            maxCount = hueCount[bucket]!;
            dominantHue = bucket * 10 + 5;
          }
        }
      }
      settings.setAccentColor(HSVColor.fromAHSV(1, dominantHue.toDouble(), 0.8, 0.9).toColor());
      settings.setExtractedColor(HSVColor.fromAHSV(1, dominantHue.toDouble(), 0.8, 0.9).toColor());
    } catch (_) {
      LogService.w('背景取色失败');
    }
  }

  void _showThemePicker(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('主题模式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              _themeOption(ctx, settings, '跟随系统', '根据系统设置自动切换', ThemeMode.system, Icons.settings_brightness_rounded),
              _themeOption(ctx, settings, '浅色', '始终使用浅色主题', ThemeMode.light, Icons.light_mode_rounded),
              _themeOption(ctx, settings, '深色', '始终使用深色主题', ThemeMode.dark, Icons.dark_mode_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, SettingsProvider settings, String label, String subtitle, ThemeMode mode, IconData icon) {
    final isSelected = settings.themeMode == mode;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
        title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        subtitle: Text(subtitle),
        trailing: isSelected ? Icon(Icons.check_rounded, color: cs.primary) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          settings.setThemeMode(mode);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ColorPickerSheet(initialColor: context.read<SettingsProvider>().accentColor),
    );
  }



  String _colorName(Color c) {
    const names = [
      '石板灰', '靛蓝', '深蓝', '青色', '翠绿', '石灰',
      '橙色', '琥珀', '深红', '紫罗兰', '粉色', '棕色',
    ];
    final idx = SettingsProvider.presetColors.indexWhere((p) => p.toARGB32() == c.toARGB32());
    if (idx >= 0) return names[idx];
    return '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

// ─── Color Picker Sheet ───

class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerSheet({required this.initialColor});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _selected;
  late TextEditingController _hexCtrl;
  double _hue = 0;
  double _sat = 1;
  double _bri = 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _hexCtrl = TextEditingController(text: _toHex(_selected));
    final hsv = HSVColor.fromColor(_selected);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _bri = hsv.value;
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _updateColor() {
    _selected = HSVColor.fromAHSV(1, _hue, _sat, _bri).toColor();
    _hexCtrl.text = _toHex(_selected);
    setState(() {});
  }

  static String _toHex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('主题颜色', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: SettingsProvider.presetColors.map((c) {
                final isSelected = c.toARGB32() == _selected.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() { _selected = c; _hexCtrl.text = _toHex(c); });
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? cs.onSurface : Colors.transparent, width: 2.5),
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: isSelected ? Icon(Icons.check_rounded, size: 18, color: cs.onSurface) : null,
                  ),
                );
              }).toList(),
            ),
            // Color picker panel
            wheel.ColorWheel(
              hue: _hue, saturation: _sat, brightness: _bri,
              onHueChanged: (v) { _hue = v; _updateColor(); },
              onSaturationChanged: (v) { _sat = v; _updateColor(); },
              onBrightnessChanged: (v) { _bri = v; _updateColor(); },
            ),
            // HEX input + Preview
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    decoration: InputDecoration(hintText: '#HEX', prefixText: 'HEX: ', prefixStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) {
                      final hex = v.replaceAll('#', '');
                      if (hex.length == 6) {
                        final c = Color(int.parse('FF$hex', radix: 16));
                        setState(() { _selected = c; _hexCtrl.text = _toHex(c); });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _selected, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: () {
                  context.read<SettingsProvider>().setAccentColor(_selected);
                  Navigator.pop(context);
                },
                child: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

