import '../entities/media_item.dart';

/// 内容仓储契约。presentation 层只依赖此接口，不感知数据来源。
abstract class MediaRepository {
  /// 拉取内容列表。
  Future<List<MediaItem>> fetchFeed();
}
