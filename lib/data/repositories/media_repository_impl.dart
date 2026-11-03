import '../../core/failure.dart';
import '../../core/logger.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/demo_media_datasource.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({DemoMediaDataSource? dataSource})
      : _dataSource = dataSource ?? const DemoMediaDataSource();

  final DemoMediaDataSource _dataSource;

  @override
  Future<List<MediaItem>> fetchFeed() async {
    try {
      return await _dataSource.loadFeed();
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      AppLog.e('MediaRepository', '加载内容列表失败', error, stackTrace);
      throw NetworkFailure('加载内容列表失败', cause: error);
    }
  }
}
