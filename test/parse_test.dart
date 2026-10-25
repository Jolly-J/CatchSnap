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

  test('Test Xiaohongshu LivePhoto Parsing', () async {
    final xhsLiveRaw = 'opppfindx9pro目前主力壳！买过设计感最强的 https://xhslink.cn/o/5wR7EIfoVrh 把文字复制好，然后去【小红书】查看详情。';
    print('\nTesting Xiaohongshu LivePhoto parsing...');
    final liveItem = await ParserFactory.parse(xhsLiveRaw);
    print(' - Live Title: ${liveItem.title}');
    print(' - isLivePhoto: ${liveItem.isLivePhoto}');
    print(' - isVideo: ${liveItem.isVideo}');
    print(' - isGallery: ${liveItem.isGallery}');
    print(' - Images count: ${liveItem.images.length}');
    print(' - LivePhoto clips: ${liveItem.livePhotoClips.length}');
    for (int i = 0; i < liveItem.images.length; i++) {
      print('   [$i] img: ${liveItem.images[i]}');
      if (i < liveItem.livePhotoClips.length) {
        print('       clip: ${liveItem.livePhotoClips[i]}');
      }
    }
    expect(liveItem.isLivePhoto, true);
    expect(liveItem.isGallery, true);
    expect(liveItem.images.length, 6);
    expect(liveItem.livePhotoClips.length, 6);
    expect(liveItem.livePhotoClips.every((c) => c.isNotEmpty), true);
  });

  test('Test Xiaohongshu Gallery High-Res Parsing', () async {
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

  test('Test Xiaohongshu Video Parsing', () async {
    final xhsRaw = 'oots | All the stuff i need, 学院风极繁叠穿太有层... https://xhslink.cn/o/4F6MsGjCECL 复制这段话，打开【小红书】就能找到对应笔记。';
    print('\nTesting Xiaohongshu video parsing...');
    final xhsItem = await ParserFactory.parse(xhsRaw);
    print('Xiaohongshu parsed:');
    print(' - Title: ${xhsItem.title}');
    print(' - Author: ${xhsItem.author}');
    expect(xhsItem.title.isNotEmpty, true);
    expect(xhsItem.videoStreams.isNotEmpty || xhsItem.images.isNotEmpty, true);
  });
}
