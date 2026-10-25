import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:douyin_downloader/parsers/parser_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Test Live Douyin and XHS Parsers', () async {
    // Test 1: Douyin
    final dyRaw = '7.46 复制打开抖音，看看【钟文泽的作品】iPhone Duo 纳米纹理屏还是贴膜？一个视频... https://v.douyin.com/MyL3zJmc9hw/ 06/21 goD:/ i@c.aA :3pm';
    print('Testing Douyin parsing...');
    final dyItem = await ParserFactory.parse(dyRaw);
    print('Douyin parsed:');
    print(' - Title: ${dyItem.title}');
    print(' - Author: ${dyItem.author}');
    print(' - Avatar: ${dyItem.authorAvatar}');
    print(' - Video Streams: ${dyItem.videoStreams.map((s) => s.gearName).toList()}');
    print(' - Cover: ${dyItem.coverUrl}');
    expect(dyItem.title.contains('iPhone'), true);
    expect(dyItem.authorAvatar.isNotEmpty, true);
    expect(dyItem.videoStreams.isNotEmpty, true);

    // Test 2: Xiaohongshu Video
    final xhsRaw = 'oots | All the stuff i need, 学院风极繁叠穿太有层... https://xhslink.cn/o/4F6MsGjCECL 复制这段话，打开【小红书】就能找到对应笔记。';
    print('\nTesting Xiaohongshu video parsing...');
    final xhsItem = await ParserFactory.parse(xhsRaw);
    print('Xiaohongshu parsed:');
    print(' - Title: ${xhsItem.title}');
    print(' - Author: ${xhsItem.author}');
    print(' - Images count: ${xhsItem.images.length}');
    print(' - Video streams: ${xhsItem.videoStreams.map((s) => s.gearName).toList()}');
    print(' - Cover: ${xhsItem.coverUrl}');
    expect(xhsItem.title.isNotEmpty, true);
    expect(xhsItem.videoStreams.isNotEmpty || xhsItem.images.isNotEmpty, true);

    // Test 3: Xiaohongshu Image Gallery (High-Res check)
    final xhsImgRaw = 'https://xhslink.cn/o/5itCe6aLSCT';
    print('\nTesting Xiaohongshu gallery high-res parsing...');
    final xhsImgItem = await ParserFactory.parse(xhsImgRaw);
    print(' - Gallery Title: ${xhsImgItem.title}');
    print(' - Gallery Images (${xhsImgItem.images.length}):');
    for (final img in xhsImgItem.images) {
      print('   * $img');
      expect(img.startsWith('https://sns-img-bd.xhscdn.com/'), true, reason: 'Should use watermark-free raw CDN');
    }
    expect(xhsImgItem.images.length, greaterThanOrEqualTo(4));
  });
}
