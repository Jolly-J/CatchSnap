import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:douyin_downloader/parsers/parser_factory.dart';
import 'package:douyin_downloader/services/download_task_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') {
          return '/tmp';
        }
        return '/tmp';
      },
    );

    // Mock permission_handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        return {1: 1}; // Granted
      },
    );
  });

  test('Test LivePhoto Full Download and Motion Photo Synthesis', () async {
    final savedFiles = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.douyin_downloader/floating'),
      (call) async {
        if (call.method == 'saveFileToGallery') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          savedFiles.add(args);
          print('Mock saveFileToGallery called: ${args['fileName']}');
          final filePath = args['filePath'] as String;
          final file = File(filePath);
          expect(file.existsSync(), true);
          final bytes = await file.readAsBytes();
          print('Saved file size: ${bytes.length} bytes');
          // 校验是否为合法的 Motion Photo JPEG
          expect(bytes[0], 0xFF);
          expect(bytes[1], 0xD8);
          // 校验是否包含 XMP MotionPhoto 声明
          final str = String.fromCharCodes(bytes.sublist(0, 8000));
          expect(str.contains('Camera:MotionPhoto="1"'), true);
          expect(str.contains('Item:Semantic="MotionPhoto"'), true);
          // 校验文件名以 .jpg 结尾，而不是 .mp4
          expect(args['fileName'].toString().endsWith('.jpg'), true);
          return true;
        }
        return null;
      },
    );

    final raw = 'opppfindx9pro目前主力壳！买过设计感最强的 https://xhslink.cn/o/5wR7EIfoVrh 把文字复制好，然后去【小红书】查看详情。';
    final item = await ParserFactory.parse(raw);
    expect(item.isLivePhoto, true);
    expect(item.images.length, 6);

    print('Starting live photo gallery download...');
    final taskId = await DownloadTaskManager.instance.startGalleryDownload(item: item);
    expect(taskId.isNotEmpty, true);

    // 等待 6 组实况照片全部下载并合成完毕
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (savedFiles.length >= item.images.length) break;
    }

    print('Total saved files count: ${savedFiles.length}');
    expect(savedFiles.length, item.images.length);

    for (int i = 0; i < savedFiles.length; i++) {
      final f = savedFiles[i];
      print('[$i] fileName: ${f['fileName']}');
      expect(f['fileName'].toString().endsWith('.jpg'), true,
          reason: '实况照片必须作为单张 .jpg 文件保存，不能产生分开的视频文件');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
