import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:bili_novel_packer/core/log_service.dart';
import 'package:bili_novel_packer/core/novel_packer.dart';
import 'package:bili_novel_packer/core/saf_helper.dart';
import 'package:bili_novel_packer/light_novel/base/light_novel_model.dart';
import 'package:bili_novel_packer/pack_argument.dart';
import 'package:path_provider/path_provider.dart';


// ─── Sealed States ───

sealed class NovelState {
  const NovelState();
}
final class NovelInitial extends NovelState {
  const NovelInitial();
}
final class NovelLoading extends NovelState {
  final String url;
  const NovelLoading(this.url);
}
final class NovelLoaded extends NovelState {
  final Novel novel;
  final Catalog catalog;
  final Volume? selectedVolume;
  const NovelLoaded(this.novel, this.catalog, this.selectedVolume);
}
final class NovelError extends NovelState {
  final String message;
  const NovelError(this.message);
}

// ─── Sealed States for Pack ───

sealed class PackState {
  const PackState();
}
final class PackIdle extends PackState {
  const PackIdle();
}
final class PackingProgress extends PackState {
  final double progress;
  final String currentOperation;
  final String? errorMessage;
  final int fileSize;
  final int totalBytes;
  final double speed;
  final Uint8List? coverData;
  const PackingProgress(this.progress, this.currentOperation, {this.errorMessage, this.fileSize = 0, this.totalBytes = 0, this.speed = 0, this.coverData});
}
final class PackCompleted extends PackState {
  final String outputPath;
  final String fileName;
  final int fileSize;
  final Uint8List? coverData;
  final String fileUri;
  const PackCompleted(this.outputPath, this.fileName, {this.fileSize = 0, this.coverData, this.fileUri = ''});
}
final class PackFailed extends PackState {
  final String message;
  const PackFailed(this.message);
}

// ─── NovelProvider ───

class NovelProvider extends ChangeNotifier {
  NovelState _state = const NovelInitial();
  NovelState get state => _state;

  NovelPacker? _packer;
  NovelPacker get packer => _packer!;

  final Map<String, Uint8List> _coverCache = {};
  final Set<String> _loadingCovers = {};

  Uint8List? getCachedCover(String url) => _coverCache[url];
  bool isCoverLoading(String url) => _loadingCovers.contains(url);

  Future<void> preloadCover(String url) async {
    if (_coverCache.containsKey(url) || _loadingCovers.contains(url)) return;
    _loadingCovers.add(url);
    notifyListeners();
    try {
      final data = await _packer!.lightNovelSource.getImage(url);
      _coverCache[url] = data;
    } catch (_) {}
    _loadingCovers.remove(url);
    notifyListeners();
  }

  Future<void> loadNovel(String url) async {
    _state = NovelLoading(url);
    _coverCache.clear();
    _loadingCovers.clear();
    notifyListeners();
    try {
      _packer = NovelPacker.fromUrl(url);
      await _packer!.init();
      final catalog = _packer!.catalog;
      _state = NovelLoaded(
        _packer!.novel,
        catalog,
        catalog.volumes.isNotEmpty ? catalog.volumes.first : null,
      );
    } catch (e) {
      _state = NovelError(e.toString());
    }
    notifyListeners();
  }

  void selectVolume(Volume v) {
    if (_state case NovelLoaded(:final novel, :final catalog)) {
      _state = NovelLoaded(novel, catalog, v);
      notifyListeners();
    }
  }
}

// ─── PackProvider ───

class PackProvider extends ChangeNotifier {
  PackState _state = const PackIdle();
  PackState get state => _state;

  bool addChapterTitle = true;
  String? outputDirectory;
  int _lastFileSize = 0;
  int _prevBytes = 0;
  int _prevTime = 0;
  double _smoothSpeed = 0;

  void setAddChapterTitle(bool v) {
    addChapterTitle = v;
    notifyListeners();
  }

  void setOutputDirectory(String? path) {
    outputDirectory = path;
    notifyListeners();
  }

  Future<String> _defaultOutputDir() async {
    try {
      await SafHelper.initBilinovelDir();
      return 'Download/bilinovel';
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
  }

  Future<void> startPacking({
    required NovelPacker packer,
    required List<Volume> volumes,
    required bool addChapterTitle,
    String? outputDirectory,
    bool useNumericId = false,
  }) async {
    _prevBytes = 0;
    _prevTime = 0;
    _smoothSpeed = 0;
    _state = const PackingProgress(0, '准备开始...');
    notifyListeners();

    try {
      final arg = PackArgument(
        addChapterTitle: addChapterTitle,
        packVolumes: volumes,
      );

      Uint8List? coverData;
      if (volumes.isNotEmpty) {
        final last = volumes.last;
        if (last.cover != null && last.cover!.isNotEmpty) {
          try {
            coverData = await packer.lightNovelSource.getImage(last.cover!);
          } catch (_) {}
        }
      }

      final subfolder = _sanitizeFolderName(useNumericId ? packer.novel.id : packer.novel.title);
      List<PackResult> results = await packer.pack(arg, onProgress: (p, msg, bytes) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_prevTime > 0) {
          final dt = (now - _prevTime) / 1000;
          final db = bytes - _prevBytes;
          if (db > 0 && dt > 0) {
            final instantSpeed = db / dt;
            _smoothSpeed = _smoothSpeed > 0
                ? 0.3 * instantSpeed + 0.7 * _smoothSpeed
                : instantSpeed;
          }
        }
        _prevBytes = bytes;
        _prevTime = now;
        _state = PackingProgress(p, msg, fileSize: _lastFileSize, totalBytes: bytes, speed: _smoothSpeed, coverData: coverData);
        notifyListeners();
      });

      String outDir = outputDirectory ?? await _defaultOutputDir();
      for (final result in results) {
        String fileUri = '';
        try {
          if (outputDirectory == null) {
            fileUri = await SafHelper.saveToBilinovel(result.fileName, result.data, subfolder: subfolder);
            if (fileUri.isEmpty) {
              outDir = await _writeToDir(outDir, result.fileName, result.data);
            }
          } else {
            outDir = await _writeToDir(outDir, result.fileName, result.data);
          }
          _lastFileSize = result.data.length;
        } on PathAccessException {
          outDir = await _defaultOutputDir();
          LogService.w("所选目录无写入权限，已保存至：$outDir");
          outputDirectory = null;
          fileUri = await SafHelper.saveToBilinovel(result.fileName, result.data, subfolder: subfolder);
          _lastFileSize = result.data.length;
        }
        _state = PackCompleted(outDir, result.fileName, fileSize: _lastFileSize, coverData: coverData, fileUri: fileUri);
      }
    } catch (e) {
      _state = PackFailed(e.toString());
    }
    notifyListeners();
  }

  Future<String> _writeToDir(String dir, String fileName, List<int> data) async {
    final outDir = dir;
    final d = Directory(outDir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    await File('$outDir${Platform.pathSeparator}$fileName').writeAsBytes(data);
    return outDir;
  }

  String _sanitizeFolderName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
  }

  void reset() {
    _state = const PackIdle();
    addChapterTitle = true;
    outputDirectory = null;
    notifyListeners();
  }
}
