import '../../core/config.dart';
import '../../domain/entities/media_item.dart';

/// 本地演示数据源。
///
/// 接入真实后端时新增 `MediaRemoteDataSource`，并保持 [MediaRepository] 契约不变。
class DemoMediaDataSource {
  const DemoMediaDataSource();

  Future<List<MediaItem>> loadFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const <MediaItem>[
      MediaItem(
        id: 'demo-1',
        title: '示例视频 01',
        videoUrl: AppConfig.demoVideoUrl,
        duration: Duration(seconds: 52),
      ),
      MediaItem(
        id: 'demo-2',
        title: '示例视频 02',
        videoUrl: AppConfig.demoVideoUrl,
        duration: Duration(seconds: 52),
      ),
    ];
  }
}
