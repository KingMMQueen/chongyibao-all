import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/duration_format.dart';
import 'player_controller.dart';
import 'player_kernel.dart';
import 'widgets/player_controls.dart';

/// 三端共用的播放器视图。
///
/// 结构：Texture 画面 + 手势层 + 自绘控制层。
/// 画面必须来自 [PlayerController.textureId]（原生纹理），
/// 不允许在原图层使用原生视图叠层，否则圆角、遮挡、截图都会失效。
class PlayerView extends StatefulWidget {
  const PlayerView({
    super.key,
    required this.controller,
    required this.title,
    this.onBack,
    this.aspectRatio = 16 / 9,
  });

  final PlayerController controller;
  final String title;
  final VoidCallback? onBack;
  final double aspectRatio;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  static const Duration _autoHideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;
  Timer? _hideTimer;
  Duration? _seekPreview;
  Duration _dragOrigin = Duration.zero;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    if (widget.controller.snapshot.isPlaying) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
      return;
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_autoHideDelay, () {
      if (mounted && widget.controller.snapshot.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    }
  }

  Duration _previewFromDrag(DragUpdateDetails details) {
    final Duration total = widget.controller.snapshot.duration;
    final double width = context.size?.width ?? 1;
    _dragDx += details.delta.dx;
    if (total <= Duration.zero || width <= 0) {
      return _dragOrigin;
    }
    final int deltaMs = (total.inMilliseconds * (_dragDx / width)).round();
    Duration target = _dragOrigin + Duration(milliseconds: deltaMs);
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (target > total) {
      target = total;
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? _) {
          final PlayerSnapshot snapshot = widget.controller.snapshot;
          final bool overlayVisible = _controlsVisible || !snapshot.isPlaying;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onHorizontalDragStart: (DragStartDetails _) {
              _dragOrigin = widget.controller.snapshot.position;
              _dragDx = 0;
              setState(() => _controlsVisible = true);
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              setState(() => _seekPreview = _previewFromDrag(details));
            },
            onHorizontalDragEnd: (DragEndDetails _) {
              final Duration? target = _seekPreview;
              if (target != null) {
                widget.controller.seekTo(target);
              }
              setState(() => _seekPreview = null);
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildSurface(snapshot),
                if (_seekPreview != null) _buildSeekPreview(_seekPreview!),
                if (overlayVisible)
                  PlayerControls(
                    snapshot: snapshot,
                    title: widget.title,
                    onPlayPause: widget.controller.togglePlay,
                    onSeekProgress: widget.controller.seekToProgress,
                    onSpeedTap: widget.controller.cycleSpeed,
                    onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSurface(PlayerSnapshot snapshot) {
    final int? textureId = widget.controller.textureId;
    if (textureId != null) {
      // 按真实宽高比居中留黑，避免非 16:9 视频被拉伸。
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: snapshot.aspectRatio,
            child: Texture(textureId: textureId),
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              snapshot.hasError
                  ? Icons.error_outline
                  : Icons.movie_outlined,
              color: Colors.white24,
              size: 42,
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.hasError
                  ? (snapshot.errorMessage ?? '播放失败')
                  : '模拟内核 · ${snapshot.phase.name}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekPreview(Duration target) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '${formatDuration(target)} / '
              '${formatDuration(widget.controller.snapshot.duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}


