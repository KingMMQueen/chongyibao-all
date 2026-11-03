import 'package:flutter/material.dart';

import '../../../core/duration_format.dart';
import '../player_kernel.dart';

/// 完全自绘的播放控制层。
///
/// 这是「一套代码覆盖三端」的核心展示：进度条用 [CustomPaint] 绘制，
/// 不依赖任何平台控件，因此三端表现天然一致。
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.snapshot,
    required this.title,
    required this.onPlayPause,
    required this.onSeekProgress,
    required this.onSpeedTap,
    required this.onBack,
  });

  final PlayerSnapshot snapshot;
  final String title;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeekProgress;
  final VoidCallback onSpeedTap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Color(0xCC000000)],
          stops: <double>[0.45, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: Colors.white,
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: <Widget>[
                Text(
                  formatDuration(snapshot.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  formatDuration(snapshot.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: ProgressTrack(
              progress: snapshot.progress,
              buffered: snapshot.bufferedProgress,
              color: accent,
              onSeek: onSeekProgress,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onPlayPause,
                  icon: Icon(
                    snapshot.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 30,
                  ),
                  color: Colors.white,
                ),
                TextButton(
                  onPressed: onSpeedTap,
                  child: Text(
                    '${snapshot.speed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const Spacer(),
                Text(
                  snapshot.phase.name,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 自绘进度条：支持点击与拖动定位，带缓冲进度与圆形滑块。
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.progress,
    required this.buffered,
    required this.color,
    required this.onSeek,
  });

  final double progress;
  final double buffered;
  final Color color;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        void handle(Offset localPosition) {
          if (width <= 0) {
            return;
          }
          onSeek((localPosition.dx / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => handle(d.localPosition),
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              handle(d.localPosition),
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _ProgressPainter(
                progress: progress,
                buffered: buffered,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.progress,
    required this.buffered,
    required this.color,
  });

  final double progress;
  final double buffered;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 2;
    final double cy = size.height / 2;
    final Rect track = Rect.fromLTWH(0, cy - radius, size.width, radius * 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(radius)),
      Paint()..color = Colors.white24,
    );

    final double bufferedWidth = size.width * buffered.clamp(0.0, 1.0);
    if (bufferedWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, cy - radius, bufferedWidth, radius * 2),
          const Radius.circular(radius),
        ),
        Paint()..color = Colors.white38,
      );
    }

    final double playedWidth = size.width * progress.clamp(0.0, 1.0);
    if (playedWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, cy - radius, playedWidth, radius * 2),
          const Radius.circular(radius),
        ),
        Paint()..color = color,
      );
    }

    canvas.drawCircle(Offset(playedWidth, cy), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.buffered != buffered ||
      oldDelegate.color != color;
}
