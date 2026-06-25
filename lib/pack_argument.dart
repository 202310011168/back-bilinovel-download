import 'package:bili_novel_packer/light_novel/base/light_novel_model.dart';

class PackArgument {
  final bool addChapterTitle;
  final List<Volume> packVolumes;

  const PackArgument({
    required this.addChapterTitle,
    required this.packVolumes,
  });

  @override
  String toString() {
    return 'PackArgument{addChapterTitle: $addChapterTitle, packVolumes: $packVolumes}';
  }
}
