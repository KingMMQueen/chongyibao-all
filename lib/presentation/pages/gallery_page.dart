import 'package:flutter/material.dart';

import '../../core/failure_message.dart';
import '../../platform/image/image_pick_service.dart';

/// 图集页：瀑布式网格 + 大图缩放 + 相册选择入口。
///
/// 图片展示必须走服务端缩略图参数（`?w=400&f=webp`），
/// 客户端不要直接加载原图，否则长图会 OOM。
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final ImagePickService _picker = ImagePickService();

  late final List<String> _urls = List<String>.generate(
    12,
    (int i) => 'https://picsum.photos/seed/chongyibao$i/600/800',
  );

  Future<void> _pick() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final List<PickedImage> picked = await _picker.pickImages(maxCount: 9);
      messenger.showSnackBar(
        SnackBar(content: Text('已选择 ${picked.length} 张')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeFailure(error))),
      );
    }
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImageViewerPage(urls: _urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图集')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('选择图片'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
        itemCount: _urls.length,
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () => _openViewer(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                _urls[index],
                fit: BoxFit.cover,
                cacheWidth: 360,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) {
                    return child;
                  }
                  return const ColoredBox(color: Color(0xFF1C1F26));
                },
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF1C1F26),
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white24),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (BuildContext context, int index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                urls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white24,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
