import 'dart:async';
import 'dart:typed_data';

import 'package:bili_novel_packer/assets/assets.dart';
import 'package:bili_novel_packer/core/epub_packer.dart' as core;
import 'package:bili_novel_packer/core/log_service.dart';
import 'package:bili_novel_packer/light_novel/base/light_novel_cover_detector.dart';
import 'package:bili_novel_packer/light_novel/base/light_novel_model.dart';
import 'package:bili_novel_packer/light_novel/base/light_novel_source.dart';
import 'package:bili_novel_packer/light_novel/bili_novel/bili_novel_source.dart';
import 'package:bili_novel_packer/light_novel/wenku_novel/wenku_novel_source.dart';
import 'package:bili_novel_packer/pack_argument.dart';
import 'package:bili_novel_packer/util/html_util.dart';
import 'package:bili_novel_packer/util/sequence.dart';
import 'package:bili_novel_packer/util/volume_util.dart';
import 'package:html/dom.dart';

class PackResult {
  final String fileName;
  final Uint8List data;

  const PackResult(this.fileName, this.data);
}

class NovelPacker {
  static final List<LightNovelSource> sources = [
    BiliNovelSource(),
    WenkuNovelSource()
  ];

  String url;
  LightNovelSource lightNovelSource;

  final Sequence _imageSequence = Sequence();
  final Sequence _chapterSequence = Sequence();

  late Novel novel;
  late Catalog catalog;

  NovelPacker._(this.lightNovelSource, this.url);

  factory NovelPacker.fromUrl(String url) {
    for (var source in sources) {
      if (source.supportUrl(url)) {
        return NovelPacker._(source, url);
      }
    }
    throw ArgumentError("Unsupported url: $url");
  }

  Future<Novel> init({
    Function(Novel novel)? novelCallback,
    Function(Catalog catalog)? catalogCallback,
  }) async {
    novel = await getNovel();
    novelCallback?.call(novel);
    catalog = await getCatalog();
    catalogCallback?.call(catalog);
    return novel;
  }

  Future<Novel> getNovel() async {
    return lightNovelSource.getNovel(url).then((novel) => this.novel = novel);
  }

  Future<Catalog> getCatalog() async {
    return lightNovelSource
        .getNovelCatalog(novel)
        .then((catalog) => this.catalog = catalog);
  }

  Future<List<PackResult>> pack(PackArgument arg, {Function(double, String, int)? onProgress}) async {
    List<PackResult> results = [];
    int totalBytes = 0;

    void addBytes(int b) { totalBytes += b; onProgress?.call(0, "处理中...", totalBytes); }

    for (var volume in arg.packVolumes) {
      LogService.i("开始打包 ${volume.catalog.novel.title} ${volume.volumeName}");
      _imageSequence.reset();
      _chapterSequence.reset();
      onProgress?.call(0, "正在处理 ${volume.volumeName}...", totalBytes);
      Uint8List bytes = await _packVolume(volume, arg.addChapterTitle, addBytes);
      totalBytes += bytes.length;
      addBytes(0);
      results.add(PackResult(_getEpubName(volume), bytes));
      LogService.i("打包完成 ${volume.catalog.novel.title} ${volume.volumeName}");
      onProgress?.call(1, "打包完成 ${volume.volumeName}", totalBytes);
    }

    return results;
  }

  Future<Document> _resolveChapter(
    Chapter chapter,
    core.EpubPacker packer,
    bool addChapterTitle, [
    LightNovelCoverDetector? detector,
    Function(int)? onDataBytes,
  ]) async {
    Document doc = await lightNovelSource.getNovelChapter(chapter);
    onDataBytes?.call(doc.outerHtml.length);
    await _resolveImages(doc, packer, detector, onDataBytes);

    if (addChapterTitle) {
      doc.head!.append(Element.html(
        '<link rel="stylesheet" type="text/css" href="styles/style.css">',
      ));
      var firstChild = doc.body!.firstChild;
      Node chapterTitle = Element.html(
        '<div class="chapter-title">${chapter.chapterName}</div>',
      );
      doc.body!.insertBefore(chapterTitle, firstChild);
    }
    LogService.i("OK ${chapter.volume.volumeName} ${chapter.chapterName}");
    return doc;
  }

  Future<Uint8List> _getSingleImage(String src) async {
    try {
      return lightNovelSource.getImage(src);
    } catch (e) {
      return Uint8List(0);
    }
  }

  Future<Uint8List> _packVolume(
    Volume volume,
    bool addChapterTitle, [
    Function(int)? onDataBytes,
  ]) async {
    LogService.i("开始打包 ${volume.volumeName}...");
    core.EpubPacker packer = core.EpubPacker();
    packer.docTitle = "${volume.catalog.novel.title} ${volume.volumeName}";
    if (volume.volumeName.startsWith(volume.catalog.novel.title)) {
      packer.docTitle = volume.volumeName;
    }
    packer.creator = volume.catalog.novel.author;
    packer.source = novel.url;
    packer.publisher = novel.publisher;
    packer.subjects = novel.tags ?? [];
    packer.description = novel.description;

    packer.calibreSeriesIndex = VolumeUtil.getSeriesIndex(volume.volumeName);
    if (packer.calibreSeriesIndex != null) {
      packer.calibreSeries = volume.catalog.novel.title;
    }

    LightNovelCoverDetector detector = LightNovelCoverDetector();

    if (addChapterTitle) {
      packer.addStylesheet(styleCss());
    }

    List<Future<Document>> futures = volume.chapters
        .map(
          (chapter) =>
              _resolveChapter(chapter, packer, addChapterTitle, detector, onDataBytes),
        )
        .toList();

    List<Document> chapterDocuments = await Future.wait(futures);

    for (int i = 0; i < chapterDocuments.length; i++) {
      var chapter = volume.chapters[i];
      var document = chapterDocuments[i];
      _addTitle(document, chapter.chapterName);
      String html = _closeTag(document);
      html = _appendXmlDeclare(html);
      packer.addChapter(
        name:
            "OEBPS/chapter${_chapterSequence.next.toString().padLeft(6, "0")}.xhtml",
        title: chapter.chapterName,
        chapterContent: html,
      );
    }

    await _resolveCover(volume, packer, detector);
    return packer.packToBytes();
  }

  Future<void> _resolveImages(
    Document doc,
    core.EpubPacker packer,
    LightNovelCoverDetector? detector, [
    Function(int)? onDataBytes,
  ]) async {
    List<Element> imgList = doc.querySelectorAll("img");
    List<Future<({Element img, Uint8List data})?>> futures = [];
    for (var img in imgList) {
      futures.add(_resolveSingleImage(img, packer, detector, onDataBytes));
    }
    var results = await Future.wait(futures);
    for (final result in results) {
      if (result == null) continue;
      final (:img, :data) = result;
      String name = "${_imageSequence.next.toString().padLeft(6, '0')}.jpg";
      String relativeSrc = "images/$name";
      packer.addImage(name: "OEBPS/$relativeSrc", data: data);
      String? src = img.attributes["src"];
      img.attributes["src"] = relativeSrc;
      try {
        detector?.add("OEBPS/$relativeSrc", data);
      } on UnsupportedImageException catch (e) {
        LogService.w("$src ${e.message}");
      }
    }

    HTMLUtil.wrapDuoKanImage(doc.body!);
  }

  Future<({Element img, Uint8List data})?> _resolveSingleImage(
    Element img,
    core.EpubPacker packer,
    LightNovelCoverDetector? detector, [
    Function(int)? onDataBytes,
  ]) async {
    String? src = img.attributes["src"];
    if (src == null || src.isEmpty) {
      return null;
    }
    Uint8List imageData = await _getSingleImage(src);
    if (imageData.isEmpty) {
      LogService.w("$src 图片下载失败");
      return null;
    }
    onDataBytes?.call(imageData.length);
    return (img: img, data: imageData);
  }

  Future<void> _resolveCover(
    Volume volume,
    core.EpubPacker packer,
    LightNovelCoverDetector coverDetector,
  ) async {
    if (volume.cover != null) {
      Uint8List coverData =
          await _getSingleImage(volume.cover!).catchError((e) {
        throw Exception("下载封面失败 ${volume.cover}\n$e");
      });
      String coverName =
          "images/${_imageSequence.next.toString().padLeft(6, '0')}.jpg";
      packer.addImage(name: "OEBPS/$coverName", data: coverData);
      packer.cover = coverName;
    } else {
      String? cover = coverDetector.detectCover();
      if (cover != null) {
        packer.cover = cover.replaceFirst("OEBPS/", "");
      }
    }
  }

  String _getEpubName(Volume volume) {
    String title = _sanitizeFileName(volume.catalog.novel.title);
    String volumeName = _sanitizeFileName(volume.volumeName);
    if (volumeName == "") {
      return "$title.epub";
    }
    if (volumeName.startsWith(title)) {
      return "$volumeName.epub";
    }
    return "$title $volumeName.epub";
  }

  String _sanitizeFileName(String name) {
    var keywords = {":", "*", "?", "\"", "\\", "/", "<", ">", "|", "\\0", "　"};
    for (var keyword in keywords) {
      name = name.replaceAll(keyword, " ");
    }
    if (name.startsWith(".")) {
      name = name.substring(1);
    }
    if (name.endsWith(".")) {
      name = name.substring(0, name.length - 1);
    }
    name = name.replaceAllMapped(RegExp("\\s+"), (_) => " ");
    return name.trim();
  }

  void _addTitle(Document document, String title) {
    var element = document.createElement("title");
    element.text = title;
    document.head?.append(element);
  }

  String _closeTag(Document document) {
    String html = document.outerHtml;
    RegExp regExp = RegExp("(<(?:img|link).*?)>");
    Iterable<RegExpMatch> matches = regExp.allMatches(html);
    for (var match in matches) {
      String img = match.group(0)!;
      if (!img.endsWith("/>")) {
        String newImg = "${match.group(1)!}/>";
        html = html.replaceAll(img, newImg);
      }
    }
    return html;
  }

  String _appendXmlDeclare(String html) {
    String xmlDeclare = """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
  "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
""";
    return xmlDeclare + html;
  }
}
