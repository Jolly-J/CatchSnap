/**
 * @file: download_engine.dart
 * @description: 高性能多线程分片并发下载核心引擎 (分片下载 + 媒体流直拉 + 短连接容灾与自愈)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// 下载进度回调签名：已下载字节数, 总字节数, 瞬时速度 (Bytes/s)
typedef DownloadProgressCallback = void Function(
  int downloadedBytes,
  int totalBytes,
  double speedBytesPerSecond,
);

class DownloadEngine {
  /// 单例实例
  static final DownloadEngine instance = DownloadEngine._internal();
  DownloadEngine._internal();

  /// 核心下载方法
  Future<void> download({
    required String url,
    required String destPath,
    Map<String, String>? headers,
    int concurrency = 4,
    DownloadProgressCallback? onProgress,
  }) async {
    final isImageOrSmall = _isImageOrSmallUrl(url);

    // 对于图片与小型媒体资源，直接走抗断连的独立单流引擎，避免长连接池握手冲突与连接重置
    if (isImageOrSmall) {
      await _downloadImageWithRetry(
        url: url,
        destPath: destPath,
        customHeaders: headers,
        onProgress: onProgress,
      );
      return;
    }

    final client = http.Client();
    final effectiveHeaders = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.douyin.com/',
      ...?headers,
    };

    try {
      // 1. 发起 HEAD 预检，探查服务端分片支持情况
      int totalLength = -1;
      bool acceptRanges = false;

      try {
        final headUri = Uri.parse(url);
        final headReq = http.Request('HEAD', headUri)..headers.addAll(effectiveHeaders);
        final headResp = await client.send(headReq).timeout(const Duration(seconds: 15));
        
        totalLength = headResp.contentLength ?? -1;
        final rangeHeader = headResp.headers['accept-ranges']?.toLowerCase();
        acceptRanges = rangeHeader == 'bytes';
      } catch (_) {
        // CDN 禁用 HEAD 时降级走标准流式拉取
      }

      // 2. 判断是否适合开启多线程分片（支持 Range 且体积大于 2MB）
      final shouldChunk = acceptRanges && totalLength > 2 * 1024 * 1024 && concurrency > 1;

      if (shouldChunk) {
        await _downloadChunked(
          client: client,
          url: url,
          destPath: destPath,
          totalLength: totalLength,
          concurrency: concurrency,
          headers: effectiveHeaders,
          onProgress: onProgress,
        );
      } else {
        await _downloadSingleStream(
          client: client,
          url: url,
          destPath: destPath,
          headers: effectiveHeaders,
          knownTotalLength: totalLength,
          onProgress: onProgress,
        );
      }
    } finally {
      client.close();
    }
  }

  /// 针对图片与小文件：采用 dart:io 独立短连接 + 自动指数退避重试，杜绝 Connection closed
  Future<void> _downloadImageWithRetry({
    required String url,
    required String destPath,
    Map<String, String>? customHeaders,
    DownloadProgressCallback? onProgress,
  }) async {
    const maxRetries = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = Duration.zero; // 禁用空闲连接池复用，彻底规避 socket 复用假死

      try {
        final uri = Uri.parse(url);
        final req = await httpClient.getUrl(uri);

        // 设置标准防盗链与短连接请求头
        req.headers.set('User-Agent',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1');
        req.headers.set('Referer', url.contains('xhscdn.com') ? 'https://www.xiaohongshu.com/' : 'https://www.douyin.com/');
        req.headers.set('Accept', 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8');
        req.headers.set('Connection', 'close'); // 关键：声明短连接，使 CDN 正常传输后闭环

        if (customHeaders != null) {
          customHeaders.forEach((k, v) => req.headers.set(k, v));
        }

        final resp = await req.close();
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('图片下载失败 HTTP ${resp.statusCode}');
        }

        final totalBytes = resp.contentLength > 0 ? resp.contentLength : 0;
        int downloadedBytes = 0;
        int lastSampleBytes = 0;
        int lastSampleTime = DateTime.now().millisecondsSinceEpoch;
        double currentSpeed = 0.0;

        final destFile = File(destPath);
        final sink = destFile.openWrite();

        await resp.listen((chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          final timeDiff = (now - lastSampleTime) / 1000.0;
          if (timeDiff >= 0.25) {
            final bytesDiff = downloadedBytes - lastSampleBytes;
            currentSpeed = bytesDiff / timeDiff;
            lastSampleBytes = downloadedBytes;
            lastSampleTime = now;
            onProgress?.call(downloadedBytes, totalBytes, currentSpeed);
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        // 终态进度
        onProgress?.call(downloadedBytes, downloadedBytes, currentSpeed);
        return; // 成功即返回
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      } finally {
        httpClient.close(force: true);
      }
    }

    if (lastError != null) throw lastError;
  }

  bool _isImageOrSmallUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('webpic') ||
        lower.contains('xhscdn.com') ||
        lower.contains('.jpg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.jpeg') ||
        lower.contains('douyinpic.com');
  }

  // ── 多线程并发分片实现 (针对大视频) ──────────────────────────────
  Future<void> _downloadChunked({
    required http.Client client,
    required String url,
    required String destPath,
    required int totalLength,
    required int concurrency,
    required Map<String, String> headers,
    DownloadProgressCallback? onProgress,
  }) async {
    final chunkSize = (totalLength / concurrency).ceil();
    final partDownloadedBytes = List<int>.filled(concurrency, 0);

    int lastSampleBytes = 0;
    int lastSampleTime = DateTime.now().millisecondsSinceEpoch;
    double currentSpeed = 0.0;

    void updateProgress() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDiff = (now - lastSampleTime) / 1000.0;

      // 严格节流：每 250ms 触发一次 UI 与通知进度回调，彻底避免高频事件淹没主线程
      if (timeDiff >= 0.25) {
        final totalDownloaded = partDownloadedBytes.reduce((a, b) => a + b);
        final bytesDiff = totalDownloaded - lastSampleBytes;
        currentSpeed = bytesDiff / timeDiff;
        lastSampleBytes = totalDownloaded;
        lastSampleTime = now;
        onProgress?.call(totalDownloaded, totalLength, currentSpeed);
      }
    }

    final tasks = List.generate(concurrency, (index) async {
      final start = index * chunkSize;
      final end = (index == concurrency - 1) ? totalLength - 1 : (start + chunkSize - 1);

      final partFile = File('$destPath.part_$index');
      final chunkHeaders = {
        ...headers,
        'Range': 'bytes=$start-$end',
      };

      final req = http.Request('GET', Uri.parse(url))..headers.addAll(chunkHeaders);
      final resp = await client.send(req);

      if (resp.statusCode != 206 && resp.statusCode != 200) {
        throw Exception('分片拉取失败: part_$index HTTP ${resp.statusCode}');
      }

      final sink = partFile.openWrite();
      await resp.stream.listen((chunk) {
        sink.add(chunk);
        partDownloadedBytes[index] += chunk.length;
        updateProgress();
      }).asFuture();

      await sink.flush();
      await sink.close();
    });

    await Future.wait(tasks);

    final finalFile = File(destPath);
    final outputSink = finalFile.openWrite();

    for (int i = 0; i < concurrency; i++) {
      final part = File('$destPath.part_$i');
      if (await part.exists()) {
        await outputSink.addStream(part.openRead());
        await part.delete();
      }
    }

    await outputSink.flush();
    await outputSink.close();

    onProgress?.call(totalLength, totalLength, 0.0);
  }

  // ── 单线程流式下载（降级保障）──────────────────────────────────
  Future<void> _downloadSingleStream({
    required http.Client client,
    required String url,
    required String destPath,
    required Map<String, String> headers,
    required int knownTotalLength,
    DownloadProgressCallback? onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse(url))..headers.addAll(headers);
    final resp = await client.send(req);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('网络下载请求失败 HTTP: ${resp.statusCode}');
    }

    final totalBytes = (resp.contentLength != null && resp.contentLength! > 0)
        ? resp.contentLength!
        : knownTotalLength;

    int downloadedBytes = 0;
    int lastSampleBytes = 0;
    int lastSampleTime = DateTime.now().millisecondsSinceEpoch;
    double currentSpeed = 0.0;

    final destFile = File(destPath);
    final sink = destFile.openWrite();

    await resp.stream.listen((chunk) {
      sink.add(chunk);
      downloadedBytes += chunk.length;

      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDiff = (now - lastSampleTime) / 1000.0;
      if (timeDiff >= 0.25) {
        final bytesDiff = downloadedBytes - lastSampleBytes;
        currentSpeed = bytesDiff / timeDiff;
        lastSampleBytes = downloadedBytes;
        lastSampleTime = now;
        onProgress?.call(downloadedBytes, totalBytes, currentSpeed);
      }
    }).asFuture();

    await sink.flush();
    await sink.close();

    onProgress?.call(downloadedBytes, totalBytes > 0 ? totalBytes : downloadedBytes, currentSpeed);
  }
}
