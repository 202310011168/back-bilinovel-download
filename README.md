# 轻小说打包器

将支持的轻小说网站中的小说打包成 EPUB 格式，包含插图和目录。

- 哔哩轻小说 ([linovelib.com](https://www.linovelib.com))
- 轻小说文库 ([wenku8.net](https://www.wenku8.net/login.php))

## 下载

[Releases](https://github.com/202310011168/back-bilinovel-download/releases) 页面下载 APK 安装到 Android 手机。

## 构建

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

APK 输出在 `build/app/outputs/flutter-apk/`。

## 致谢

基于 [Montaro2017/bili_novel_packer](https://github.com/Montaro2017/bili_novel_packer) v0.2.43 原作者 Spark 的 CLI 版本，转换为 Flutter Android 应用。
