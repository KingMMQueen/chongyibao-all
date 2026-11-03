import 'package:flutter/material.dart';

import '../../domain/repositories/media_repository.dart';
import 'gallery_page.dart';
import 'home_page.dart';

/// 应用主框架：首页 + 图集两个 tab。
class RootPage extends StatefulWidget {
  const RootPage({super.key, required this.repository});

  final MediaRepository repository;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          HomePage(repository: widget.repository),
          const GalleryPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle_fill),
            label: '视频',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '图集',
          ),
        ],
      ),
    );
  }
}
