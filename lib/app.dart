import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bili_novel_packer/ui/providers/novel_provider.dart';
import 'package:bili_novel_packer/ui/providers/settings_provider.dart';
import 'package:bili_novel_packer/ui/screens/url_input_screen.dart';
import 'package:bili_novel_packer/ui/screens/catalog_screen.dart';
import 'package:bili_novel_packer/ui/screens/progress_screen.dart';
import 'package:bili_novel_packer/ui/screens/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', pageBuilder: _slideRight(const UrlInputScreen())),
    GoRoute(path: '/catalog', pageBuilder: _slideRight(const CatalogScreen())),
    GoRoute(path: '/progress', pageBuilder: _slideRight(const ProgressScreen())),
    GoRoute(path: '/settings', pageBuilder: _slideRight(const SettingsScreen())),
  ],
);

GoRouterPageBuilder _slideRight(Widget child) {
  return (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      );
}

Widget _bgImage(SettingsProvider s) {
  switch (s.backgroundFit) {
    case 1: return Image.file(File(s.backgroundPath!), repeat: ImageRepeat.repeat, width: double.infinity, height: double.infinity);
    case 2: return Image.file(File(s.backgroundPath!), fit: BoxFit.fill, width: double.infinity, height: double.infinity);
    default: return Image.file(File(s.backgroundPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }
}

class BiliNovelPackerApp extends StatelessWidget {
  final SettingsProvider settings;

  const BiliNovelPackerApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => NovelProvider()),
        ChangeNotifierProvider(create: (_) => PackProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: '轻小说打包器',
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            themeMode: settings.themeMode,
            theme: settings.buildTheme(Brightness.light),
            darkTheme: settings.buildTheme(Brightness.dark),
            builder: (context, child) {
              if (settings.backgroundPath == null) return child!;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: settings.backgroundOpacity,
                      child: _bgImage(settings),
                    ),
                  ),
                  child!,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
