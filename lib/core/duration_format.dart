/// 将时长格式化为 `mm:ss` 或 `h:mm:ss`。
String formatDuration(Duration value) {
  final Duration d = value.isNegative ? Duration.zero : value;
  final int hours = d.inHours;
  final int minutes = d.inMinutes.remainder(60);
  final int seconds = d.inSeconds.remainder(60);
  final String mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$mm:$ss';
}
