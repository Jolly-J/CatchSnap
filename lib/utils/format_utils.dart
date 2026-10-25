/**
 * @file: format_utils.dart
 * @description: 数据度量衡与格式化纯函数工具集
 * @author: Antigravity
 * @version: 2.0.0
 */

class FormatUtils {
  /// 格式化字节尺寸 (如 14.5 MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// 格式化瞬时网速 (如 3.8 MB/s)
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0.0 KB/s';
    if (bytesPerSecond < 1024 * 1024) {
      final kb = bytesPerSecond / 1024;
      return '${kb.toStringAsFixed(1)} KB/s';
    }
    final mb = bytesPerSecond / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB/s';
  }

  /// 格式化媒体时长毫秒数 (如 01:25)
  static String formatDuration(int durationMs) {
    if (durationMs <= 0) return '00:00';
    final seconds = (durationMs / 1000).floor();
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  /// 格式化时间戳 (秒级或毫秒级) 为可读日期
  static String formatTimestamp(int timestamp) {
    if (timestamp <= 0) return '';
    // 判断是秒还是毫秒
    final ms = timestamp < 10000000000 ? timestamp * 1000 : timestamp;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
