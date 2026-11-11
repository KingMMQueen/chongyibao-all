import 'package:flutter/material.dart';

import 'data/repositories/media_repository_impl.dart';
import 'domain/repositories/media_repository.dart';
import 'presentation/pages/root_page.dart';

/// 应用根组件。三端共用同一份，不含任何平台判断。
class ChongYiBaoApp extends StatelessWidget {
  const ChongYiBaoApp({super.key, this.repository});

  final MediaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final MediaRepository mediaRepository =
        repository ?? MediaRepositoryImpl();

    return MaterialApp(
      title: '宠医宝',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3D7EFF),
        scaffoldBackgroundColor: const Color(0xFF101114),
      ),
      home: RootPage(repository: mediaRepository),
    );
  }
}
