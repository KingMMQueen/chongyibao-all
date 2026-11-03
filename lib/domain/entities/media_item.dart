import 'package:flutter/foundation.dart';

/// 内容条目：一条视频 + 一组图片。
@immutable
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.coverUrl,
    this.duration,
    this.images = const <String>[],
  });

  final String id;
  final String title;
  final String videoUrl;
  final String? coverUrl;
  final Duration? duration;
  final List<String> images;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final Object? rawDuration = json['duration_ms'];
    return MediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      videoUrl: json['video_url'] as String,
      coverUrl: json['cover_url'] as String?,
      duration: rawDuration is int ? Duration(milliseconds: rawDuration) : null,
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'video_url': videoUrl,
        'cover_url': coverUrl,
        'duration_ms': duration?.inMilliseconds,
        'images': images,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MediaItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
