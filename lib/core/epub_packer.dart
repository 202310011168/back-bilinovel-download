import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bili_novel_packer/epub_packer/epub_constant.dart';
import 'package:bili_novel_packer/epub_packer/epub_navigator.dart';
import 'package:bili_novel_packer/epub_packer/epub_opf.dart';
import 'package:bili_novel_packer/media_type.dart' as epub_media_type;
import 'package:bili_novel_packer/media_type.dart';
import 'package:bili_novel_packer/util/url_util.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class EpubPacker {
  static const Utf8Encoder _utf8Encoder = Utf8Encoder();

  final EpubNavigator _navigator = EpubNavigator();
  final EpubOpenPackageFormat _opf = EpubOpenPackageFormat();
  final List<ArchiveFile> archiveFiles = [];

  String get docTitle => _navigator.docTitle;

  set docTitle(String value) {
    _navigator.docTitle = value;
    _opf.docTitle = value;
  }

  String get bookUuid => _navigator.bookUuid;

  set bookUuid(String value) {
    _navigator.bookUuid = value;
    _opf.bookUuid = value;
  }

  String get creator => _opf.creator;

  set creator(String value) => _opf.creator = value;

  String? get source => _opf.metaData.source;

  set source(String? source) => _opf.metaData.source = source;

  String? get publisher => _opf.metaData.publisher;

  set publisher(String? publisher) => _opf.metaData.publisher = publisher;

  List<String> get subjects => _opf.metaData.subjects;

  set subjects(List<String> subjects) => _opf.metaData.subjects = subjects;

  String? get description => _opf.metaData.description;

  set description(String? description) =>
      _opf.metaData.description = description;

  String? get cover => _opf.cover;

  set cover(String? id) => _opf.cover = id;

  String? get calibreSeries => _opf.calibreSeries;

  set calibreSeries(String? calibreSeries) =>
      _opf.calibreSeries = calibreSeries;

  num? get calibreSeriesIndex => _opf.calibreSeriesIndex;

  set calibreSeriesIndex(num? calibreSeriesIndex) =>
      _opf.calibreSeriesIndex = calibreSeriesIndex;

  EpubPacker();

  void addArchiveFile(ArchiveFile archiveFile, [int? index]) {
    if (!_existArchiveFile(archiveFile)) {
      if (index != null) {
        archiveFiles.insert(0, archiveFile);
      } else {
        archiveFiles.add(archiveFile);
      }
    }
  }

  bool _existArchiveFile(ArchiveFile file) {
    for (var archiveFile in archiveFiles) {
      if (archiveFile.name == file.name) {
        return true;
      }
    }
    return false;
  }

  void addChapter({
    String? id,
    String mediaType = epub_media_type.xhtml,
    bool addNavPoint = true,
    required String name,
    required String title,
    required String chapterContent,
  }) {
    String href = path.relative(name, from: "OEBPS");
    id ??= href;
    Uint8List utf8Uint8List = _utf8Encoder.convert(chapterContent);
    addArchiveFile(
      ArchiveFile(name, utf8Uint8List.length, utf8Uint8List),
    );
    _opf.addChapter(
      ManifestItem(id, href, mediaType),
    );
    if (addNavPoint) {
      NavPoint navPoint = NavPoint(title, src: href);
      _navigator.addNavPoint(navPoint);
    }
  }

  void addImage({
    String? id,
    String mediaType = epub_media_type.jpeg,
    required String name,
    required Uint8List data,
  }) {
    String href = path.relative(name, from: "OEBPS");
    id ??= href;
    id = _handleId(id);
    addArchiveFile(
      ArchiveFile(name, data.length, data),
    );
    _opf.addImage(ManifestItem(id, href, mediaType));
  }

  void addStylesheet(ArchiveFile archiveFile) {
    String id = URLUtil.getFileName(archiveFile.name);
    String href = path.relative(archiveFile.name, from: "OEBPS");
    id = _handleId(id);
    addArchiveFile(archiveFile);
    _opf.addStylesheet(ManifestItem(id, href, css));
  }

  void addNavPoint(NavPoint navPoint) {
    _navigator.addNavPoint(navPoint);
  }

  String _handleId(String id) {
    List<String> symbols = ["\\", "/", "."];
    for (var symbol in symbols) {
      id = id.replaceAll(symbol, "_");
    }
    return id;
  }

  Uint8List packToBytes() {
    bookUuid = const Uuid().v1();
    Uint8List ncxUint8List = _utf8Encoder.convert(
      _navigator.build().toXmlString(pretty: true),
    );
    addArchiveFile(getMimeType(), 0);
    addArchiveFile(getContainer());
    addArchiveFile(
      ArchiveFile(
        "OEBPS/toc.ncx",
        ncxUint8List.length,
        ncxUint8List,
      ),
    );
    Uint8List opfUint8List = _utf8Encoder.convert(
      _opf.build().toXmlString(pretty: true),
    );
    addArchiveFile(
      ArchiveFile(
        "OEBPS/content.opf",
        opfUint8List.length,
        opfUint8List,
      ),
    );

    final archive = Archive();
    for (var archiveFile in archiveFiles) {
      archive.addFile(archiveFile);
    }
    final bytes = ZipEncoder().encode(archive, level: Deflate.NO_COMPRESSION);
    return Uint8List.fromList(bytes!);
  }
}
