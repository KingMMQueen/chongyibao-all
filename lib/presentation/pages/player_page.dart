import 'package:flutter/material.dart';

import '../../core/failure_message.dart';
import '../../core/logger.dart';
import '../../domain/entities/media_item.dart';
import '../../platform/media/kernel_factory.dart';
import '../../platform/media/player_controller.dart';
import '../../platform/media/player_view.dart';

/// 视频播放页。
///
/// 页面本身不感知平台：内核由 [PlayerKernelFactory] 注入，
/// 换内核不需要改动此文件。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = PlayerController(kernel: PlayerKernelFactory.create());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _controller.initialize(widget.item.videoUrl);
    } catch (error, stackTrace) {
      AppLog.e('PlayerPage', '打开媒体失败', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            PlayerView(
              controller: _controller,
              title: widget.item.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                color: const Color(0xFF3A1F1F),
                padding: const EdgeInsets.all(12),
                child: Text(
                  describeFailure(_error!),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前内核：${_controller.kernelName}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
