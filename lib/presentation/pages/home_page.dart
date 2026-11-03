import 'package:flutter/material.dart';

import '../../core/duration_format.dart';
import '../../core/failure_message.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import 'player_page.dart';

/// 内容列表页。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final MediaRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<MediaItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchFeed();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.fetchFeed());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频')),
      body: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<MediaItem>> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: describeFailure(snapshot.error!),
              onRetry: _reload,
            );
          }
          final List<MediaItem> items = snapshot.data ?? const <MediaItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无内容'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final MediaItem item = items[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF23262E),
                    child: Icon(Icons.play_arrow_rounded),
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    item.duration == null
                        ? '时长未知'
                        : formatDuration(item.duration!),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerPage(item: item),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 36),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
