import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:douyin_downloader/utils/motion_photo_synthesizer.dart';

void main() {
  test('Test MotionPhotoSynthesizer Synthesis', () async {
    final imgFile = File('/tmp/input.jpg');
    final videoFile = File('/tmp/input.mp4');
    final outFile = File('/tmp/test_dart_motion.jpg');

    if (!imgFile.existsSync() || !videoFile.existsSync()) {
      print('Skip: /tmp/input.jpg or /tmp/input.mp4 does not exist');
      return;
    }

    final origImgLen = imgFile.lengthSync();
    final origVideoLen = videoFile.lengthSync();

    await MotionPhotoSynthesizer.synthesize(
      imageFile: imgFile,
      videoFile: videoFile,
      outputFile: outFile,
    );

    expect(outFile.existsSync(), true);
    final outLen = outFile.lengthSync();
    print('Original Image: $origImgLen, Video: $origVideoLen -> MotionPhoto: $outLen');

    // 检查文件尾部是否正是原视频的字节
    final outBytes = await outFile.readAsBytes();
    final videoBytes = await videoFile.readAsBytes();
    expect(outBytes.length, greaterThan(origVideoLen));

    final tailBytes = outBytes.sublist(outBytes.length - origVideoLen);
    expect(tailBytes, equals(videoBytes));

    // 检查 XMP 内容是否正确包含 MotionPhoto 字段
    final contentStr = String.fromCharCodes(outBytes.sublist(0, 8000));
    expect(contentStr.contains('Camera:MotionPhoto="1"'), true);
    expect(contentStr.contains('OpCamera:MotionPhotoOwner="oplus"'), true);
    expect(contentStr.contains('OpCamera:OLivePhotoVersion="2"'), true);
    expect(contentStr.contains('Item:Semantic="MotionPhoto"'), true);
    expect(contentStr.contains('Item:Length="$origVideoLen"'), true);
    expect(contentStr.contains('GCamera:MicroVideoOffset="$origVideoLen"'), true);
  });
}
