import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Android 多厂商 (OPPO / 小米 / vivo / Google Pixel / 三星) 通用实况照片 (Motion Photo) 规范合成器
/// 负责将 JPEG 高清静态图与 MP4 实况视频切片严谨拼接为各大厂商相册通用的单张实况照片 (.jpg)
class MotionPhotoSynthesizer {
  static const List<int> _exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
  static const List<int> _xmpHeader = [
    0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x6e, 0x73, 0x2e, 0x61, 0x64,
    0x6f, 0x62, 0x65, 0x2e, 0x63, 0x6f, 0x6d, 0x2f, 0x78, 0x61, 0x70, 0x2f,
    0x31, 0x2e, 0x30, 0x2f, 0x00,
  ]; // "http://ns.adobe.com/xap/1.0/\0"
  static const List<int> _mpfHeader = [0x4d, 0x50, 0x46, 0x00]; // "MPF\0"

  /// 异步从文件合成实况照片到目标路径
  static Future<void> synthesize({
    required File imageFile,
    required File videoFile,
    required File outputFile,
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    final videoBytes = await videoFile.readAsBytes();
    final result = synthesizeBytes(
      imageBytes: imageBytes,
      videoBytes: videoBytes,
    );
    await outputFile.writeAsBytes(result, flush: true);
  }

  /// 纯内存二进制合成
  static Uint8List synthesizeBytes({
    required Uint8List imageBytes,
    required Uint8List videoBytes,
  }) {
    if (imageBytes.length < 4 || imageBytes[0] != 0xFF || imageBytes[1] != 0xD8) {
      throw FormatException('原始图片不是合法的 JPEG 格式 (缺少 SOI 0xFFD8 标识)');
    }

    final videoLength = videoBytes.length;

    // 1. 扫描原图中的各个段
    int pos = 2;
    Uint8List? originalExifTiff;
    final List<Uint8List> otherAppSegments = [];
    int sosIndex = -1;

    while (pos < imageBytes.length - 1) {
      if (imageBytes[pos] != 0xFF) break;
      final marker = imageBytes[pos + 1];
      if (marker == 0xD9 || marker == 0xDA) {
        sosIndex = pos;
        break;
      }
      if (marker == 0xD8 || marker == 0x01 || marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7)) {
        pos += 2;
        continue;
      }

      if (pos + 4 > imageBytes.length) break;
      final segLen = (imageBytes[pos + 2] << 8) | imageBytes[pos + 3];
      final segEnd = pos + 2 + segLen;
      if (segEnd > imageBytes.length) break;

      final segBytes = imageBytes.sublist(pos, segEnd);

      if (marker == 0xE1) {
        // 检查是 Exif 还是 XMP
        if (segBytes.length >= 10 && _startsWith(segBytes, 4, _exifHeader)) {
          // Exif APP1
          originalExifTiff = segBytes.sublist(10);
        } else if (segBytes.length >= 33 && _startsWith(segBytes, 4, _xmpHeader)) {
          // 旧 XMP APP1，跳过丢弃以防双 XMP 冲突
        } else {
          otherAppSegments.add(segBytes);
        }
      } else if (marker == 0xE2 && segBytes.length >= 8 && _startsWith(segBytes, 4, _mpfHeader)) {
        // 旧 MPF APP2，跳过丢弃以防长度错位
      } else {
        otherAppSegments.add(segBytes);
      }

      pos = segEnd;
    }

    if (sosIndex == -1) {
      sosIndex = pos;
    }

    // 2. 构建/更新 Exif (注入 UserComment="Oplus_8388608" 与 Xiaomi 0x8897=1)
    final newExifTiff = (originalExifTiff != null)
        ? _writeVendorExifTags(originalExifTiff)
        : _buildMinimalVendorExif();

    final exifSegLen = _exifHeader.length + newExifTiff.length + 2;
    final exifSegment = Uint8List(2 + exifSegLen)
      ..[0] = 0xFF
      ..[1] = 0xE1
      ..[2] = (exifSegLen >> 8) & 0xFF
      ..[3] = exifSegLen & 0xFF;
    exifSegment.setRange(4, 4 + _exifHeader.length, _exifHeader);
    exifSegment.setRange(4 + _exifHeader.length, 4 + _exifHeader.length + newExifTiff.length, newExifTiff);

    // 3. 构建全厂商融合 XMP
    final xmpXml = _buildUniversalXmpXml(videoLength: videoLength);
    final xmpBytes = utf8.encode(xmpXml);
    final xmpSegLen = _xmpHeader.length + xmpBytes.length + 2;
    final xmpSegment = Uint8List(2 + xmpSegLen)
      ..[0] = 0xFF
      ..[1] = 0xE1
      ..[2] = (xmpSegLen >> 8) & 0xFF
      ..[3] = xmpSegLen & 0xFF;
    xmpSegment.setRange(4, 4 + _xmpHeader.length, _xmpHeader);
    xmpSegment.setRange(4 + _xmpHeader.length, 4 + _xmpHeader.length + xmpBytes.length, xmpBytes);

    // 4. 定位 SOS 直至 EOI
    final restBytes = imageBytes.sublist(sosIndex);
    int eoiPos = -1;
    for (int i = restBytes.length - 2; i >= 0; i--) {
      if (restBytes[i] == 0xFF && restBytes[i + 1] == 0xD9) {
        eoiPos = i;
        break;
      }
    }

    final validEntropy = (eoiPos != -1)
        ? restBytes.sublist(0, eoiPos + 2)
        : (Uint8List(restBytes.length + 2)
          ..setRange(0, restBytes.length, restBytes)
          ..setRange(restBytes.length, restBytes.length + 2, const [0xFF, 0xD9]));

    // 5. 计算最终主图 Primary Image 大小以填充 MPF
    // SOI(2) + APP0(若有) + Exif(exifSegment.length) + XMP(xmpSegment.length) + MPF(74) + 其余APP段 + SOS..EOI(validEntropy.length)
    Uint8List? app0Segment;
    final List<Uint8List> remainingApps = [];
    for (final seg in otherAppSegments) {
      if (seg.length >= 2 && seg[1] == 0xE0 && app0Segment == null) {
        app0Segment = seg;
      } else {
        remainingApps.add(seg);
      }
    }

    int primarySize = 2; // SOI
    if (app0Segment != null) primarySize += app0Segment.length;
    primarySize += exifSegment.length;
    primarySize += xmpSegment.length;
    primarySize += 74; // MPF segment length
    for (final seg in remainingApps) {
      primarySize += seg.length;
    }
    primarySize += validEntropy.length;

    // 6. 构造 MPF APP2 段
    final mpfSegment = _buildMpfSegment(primarySize);

    // 7. 组装完整的主图与 MP4 尾巴
    final builder = BytesBuilder(copy: false)
      ..add(const [0xFF, 0xD8]);

    if (app0Segment != null) {
      builder.add(app0Segment);
    }
    builder.add(exifSegment);
    builder.add(xmpSegment);
    builder.add(mpfSegment);
    for (final seg in remainingApps) {
      builder.add(seg);
    }
    builder.add(validEntropy);
    builder.add(videoBytes);

    return builder.takeBytes();
  }

  static bool _startsWith(List<int> source, int offset, List<int> pattern) {
    if (offset + pattern.length > source.length) return false;
    for (int i = 0; i < pattern.length; i++) {
      if (source[offset + i] != pattern[i]) return false;
    }
    return true;
  }

  /// 构造多厂商融合的全功能 XMP 元数据
  static String _buildUniversalXmpXml({required int videoLength}) {
    return '<?xpacket begin="\uFEFF" id="W5M0MpCehiHzreSzNTczkc9d"?>\n'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">\n'
        '  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n'
        '    <rdf:Description rdf:about=""\n'
        '        xmlns:Camera="http://ns.google.com/photos/1.0/camera/"\n'
        '        xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"\n'
        '        xmlns:OpCamera="http://ns.oplus.com/photos/1.0/camera/"\n'
        '        xmlns:VCamera="http://ns.vivo.com/photos/1.0/camera/"\n'
        '        xmlns:Container="http://ns.google.com/photos/1.0/container/"\n'
        '        xmlns:Item="http://ns.google.com/photos/1.0/container/item/"\n'
        '        Camera:MotionPhoto="1"\n'
        '        Camera:MotionPhotoVersion="1"\n'
        '        Camera:MotionPhotoPresentationTimestampUs="0"\n'
        '        GCamera:MotionPhoto="1"\n'
        '        GCamera:MotionPhotoVersion="1"\n'
        '        GCamera:MotionPhotoPresentationTimestampUs="0"\n'
        '        GCamera:MicroVideo="1"\n'
        '        GCamera:MicroVideoVersion="1"\n'
        '        GCamera:MicroVideoOffset="$videoLength"\n'
        '        GCamera:MicroVideoPresentationTimestampUs="0"\n'
        '        OpCamera:MotionPhotoOwner="oplus"\n'
        '        OpCamera:OLivePhotoVersion="2"\n'
        '        OpCamera:MotionPhotoFeatureFlag="1"\n'
        '        OpCamera:VideoLength="$videoLength"\n'
        '        OpCamera:MotionPhotoPrimaryPresentationTimestampUs="0"\n'
        '        VCamera:VMotionPhotoVersion="1"\n'
        '        VCamera:VMotionPhotoSource="1"\n'
        '        VCamera:VMediaKitVersion="1.0.0.5">\n'
        '      <Container:Directory>\n'
        '        <rdf:Seq>\n'
        '          <rdf:li rdf:parseType="Resource">\n'
        '            <Container:Item\n'
        '                Item:Mime="image/jpeg"\n'
        '                Item:Semantic="Primary"\n'
        '                Item:Length="0"\n'
        '                Item:Padding="0"/>\n'
        '          </rdf:li>\n'
        '          <rdf:li rdf:parseType="Resource">\n'
        '            <Container:Item\n'
        '                Item:Mime="video/mp4"\n'
        '                Item:Semantic="MotionPhoto"\n'
        '                Item:Length="$videoLength"\n'
        '                Item:Padding="0"/>\n'
        '          </rdf:li>\n'
        '        </rdf:Seq>\n'
        '      </Container:Directory>\n'
        '    </rdf:Description>\n'
        '  </rdf:RDF>\n'
        '</x:xmpmeta>\n'
        '<?xpacket end="w"?>';
  }

  /// 构造 CIPA DC-007 标准的 APP2 MPF (Multi-Picture Format) 段 (74 字节)
  static Uint8List _buildMpfSegment(int primarySize) {
    final bytes = Uint8List(74);
    final bd = ByteData.sublistView(bytes);

    // APP2 marker and length
    bd.setUint8(0, 0xFF);
    bd.setUint8(1, 0xE2);
    bd.setUint16(2, 72, Endian.big); // 74 - 2

    // MPF\0
    bytes[4] = 0x4D;
    bytes[5] = 0x50;
    bytes[6] = 0x46;
    bytes[7] = 0x00;

    // TIFF Header (Little Endian "II")
    // Offset 8 in bytes, offset 0 in MPF TIFF:
    bd.setUint8(8, 0x49);
    bd.setUint8(9, 0x49);
    bd.setUint16(10, 42, Endian.little);
    bd.setUint32(12, 8, Endian.little); // IFD offset = 8

    // IFD0 (Offset 16 in bytes, offset 8 in TIFF):
    // 3 entries
    bd.setUint16(16, 3, Endian.little);

    // Entry 1: 0xB000 MPFVersion, UNDEFINED(7), count=4, value="0100"
    bd.setUint16(18, 0xB000, Endian.little);
    bd.setUint16(20, 7, Endian.little);
    bd.setUint32(22, 4, Endian.little);
    bytes[26] = 0x30; // '0'
    bytes[27] = 0x31; // '1'
    bytes[28] = 0x30; // '0'
    bytes[29] = 0x30; // '0'

    // Entry 2: 0xB001 NumberOfImages, LONG(4), count=1, value=1
    bd.setUint16(30, 0xB001, Endian.little);
    bd.setUint16(32, 4, Endian.little);
    bd.setUint32(34, 1, Endian.little);
    bd.setUint32(38, 1, Endian.little);

    // Entry 3: 0xB002 MPEntry, UNDEFINED(7), count=16, offset to MPEntry (50)
    // Offset calculation: 8 (TIFF header) + 2 (count) + 3*12 (entries) + 4 (next IFD) = 50
    bd.setUint16(42, 0xB002, Endian.little);
    bd.setUint16(44, 7, Endian.little);
    bd.setUint32(46, 16, Endian.little);
    bd.setUint32(50, 50, Endian.little);

    // Next IFD = 0 (offset 54 in bytes)
    bd.setUint32(54, 0, Endian.little);

    // MPEntry Data (offset 58 in bytes, offset 50 in TIFF, 16 bytes):
    // Attributes: 0x00030000 (Big Endian in MP Entry specs: Baseline MP Primary Image)
    bd.setUint32(58, 0x00030000, Endian.big);
    // Primary size (Big Endian)
    bd.setUint32(62, primarySize, Endian.big);
    // Offset (4 bytes) & dep images (4 bytes) (all zero)
    bd.setUint32(66, 0, Endian.big);
    bd.setUint32(70, 0, Endian.big);

    return bytes;
  }

  /// 源图无 Exif 时构建最小合规 Exif (小端 TIFF)
  static Uint8List _buildMinimalVendorExif() {
    // 包含:
    // IFD0:
    //   - 0x8769 (ExifOffset) -> 指向 ExifIFD
    //   - 0x8897 (Xiaomi) -> 1
    // ExifIFD:
    //   - 0x9286 (UserComment) -> "ASCII\0\0\0Oplus_8388608"
    final userComment = utf8.encode('ASCII\x00\x00\x00Oplus_8388608');
    const ifd0Offset = 8;
    const ifd0Entries = 2;
    const ifd0Size = 2 + ifd0Entries * 12 + 4; // 30 bytes
    const exifIfdOffset = ifd0Offset + ifd0Size; // 38
    const exifIfdEntries = 1;
    const exifIfdSize = 2 + exifIfdEntries * 12 + 4; // 18 bytes
    const userCommentOffset = exifIfdOffset + exifIfdSize; // 56

    final totalTiffSize = userCommentOffset + userComment.length;
    final tiff = Uint8List(totalTiffSize);
    final bd = ByteData.sublistView(tiff);

    // TIFF Header
    tiff[0] = 0x49; // 'I'
    tiff[1] = 0x49; // 'I'
    bd.setUint16(2, 42, Endian.little);
    bd.setUint32(4, ifd0Offset, Endian.little);

    // IFD0
    bd.setUint16(ifd0Offset, ifd0Entries, Endian.little);
    // 0x8769 ExifOffset, LONG(4), count=1, value=exifIfdOffset
    bd.setUint16(ifd0Offset + 2, 0x8769, Endian.little);
    bd.setUint16(ifd0Offset + 4, 4, Endian.little);
    bd.setUint32(ifd0Offset + 6, 1, Endian.little);
    bd.setUint32(ifd0Offset + 10, exifIfdOffset, Endian.little);
    // 0x8897 Xiaomi MicroVideo, BYTE(1), count=1, value=1
    bd.setUint16(ifd0Offset + 14, 0x8897, Endian.little);
    bd.setUint16(ifd0Offset + 16, 1, Endian.little);
    bd.setUint32(ifd0Offset + 18, 1, Endian.little);
    bd.setUint8(ifd0Offset + 22, 1);
    // Next IFD = 0
    bd.setUint32(ifd0Offset + 26, 0, Endian.little);

    // ExifIFD
    bd.setUint16(exifIfdOffset, exifIfdEntries, Endian.little);
    // 0x9286 UserComment, UNDEFINED(7), count=21, offset=userCommentOffset
    bd.setUint16(exifIfdOffset + 2, 0x9286, Endian.little);
    bd.setUint16(exifIfdOffset + 4, 7, Endian.little);
    bd.setUint32(exifIfdOffset + 6, userComment.length, Endian.little);
    bd.setUint32(exifIfdOffset + 10, userCommentOffset, Endian.little);
    // Next IFD = 0
    bd.setUint32(exifIfdOffset + 14, 0, Endian.little);

    // UserComment Payload
    tiff.setRange(userCommentOffset, userCommentOffset + userComment.length, userComment);

    return tiff;
  }

  /// 在已有 TIFF 尾部安全追加 UserComment 与 Xiaomi 标记，绝不移动或损坏原条目
  static Uint8List _writeVendorExifTags(Uint8List tiff) {
    if (tiff.length < 8) return _buildMinimalVendorExif();

    final isLittleEndian = (tiff[0] == 0x49 && tiff[1] == 0x49);
    final isBigEndian = (tiff[0] == 0x4D && tiff[1] == 0x4D);
    if (!isLittleEndian && !isBigEndian) return _buildMinimalVendorExif();

    final endian = isLittleEndian ? Endian.little : Endian.big;
    final bd = ByteData.sublistView(tiff);

    final magic = bd.getUint16(2, endian);
    if (magic != 42) return _buildMinimalVendorExif();

    final ifd0Offset = bd.getUint32(4, endian);
    if (ifd0Offset + 2 > tiff.length) return _buildMinimalVendorExif();

    // 读取 IFD0 条目
    final ifd0Count = bd.getUint16(ifd0Offset, endian);
    if (ifd0Count > 4096 || ifd0Offset + 2 + ifd0Count * 12 + 4 > tiff.length) {
      return _buildMinimalVendorExif();
    }

    final Map<int, _IfdEntry> ifd0Entries = {};
    for (int i = 0; i < ifd0Count; i++) {
      final base = ifd0Offset + 2 + i * 12;
      final tag = bd.getUint16(base, endian);
      final type = bd.getUint16(base + 2, endian);
      final count = bd.getUint32(base + 4, endian);
      final raw = tiff.sublist(base + 8, base + 12);
      ifd0Entries[tag] = _IfdEntry(tag, type, count, raw);
    }
    final nextIfd0 = bd.getUint32(ifd0Offset + 2 + ifd0Count * 12, endian);

    // 读取 ExifIFD (若存在)
    final Map<int, _IfdEntry> exifEntries = {};
    int exifNext = 0;
    if (ifd0Entries.containsKey(0x8769)) {
      final exifEntry = ifd0Entries[0x8769]!;
      final exifPointer = _decodePointer(exifEntry, endian);
      if (exifPointer != null && exifPointer + 2 <= tiff.length) {
        final count = bd.getUint16(exifPointer, endian);
        if (count <= 4096 && exifPointer + 2 + count * 12 + 4 <= tiff.length) {
          for (int i = 0; i < count; i++) {
            final base = exifPointer + 2 + i * 12;
            final tag = bd.getUint16(base, endian);
            final type = bd.getUint16(base + 2, endian);
            final c = bd.getUint32(base + 4, endian);
            final raw = tiff.sublist(base + 8, base + 12);
            exifEntries[tag] = _IfdEntry(tag, type, c, raw);
          }
          exifNext = bd.getUint32(exifPointer + 2 + count * 12, endian);
        }
      }
    }

    // 在原有 TIFF 长度末尾对齐开始追加新的 ExifIFD 与 IFD0
    int baseOffset = tiff.length + (tiff.length % 2);
    final appendRegion = BytesBuilder();
    while (tiff.length + appendRegion.length < baseOffset) {
      appendRegion.addByte(0);
    }

    void align2() {
      if ((baseOffset + appendRegion.length) % 2 != 0) {
        appendRegion.addByte(0);
      }
    }

    int place(List<int> payload) {
      align2();
      final offset = baseOffset + appendRegion.length;
      appendRegion.add(payload);
      return offset;
    }

    // 1) 追加 UserComment 数据: "ASCII\0\0\0Oplus_8388608"
    final userCommentValue = utf8.encode('ASCII\x00\x00\x00Oplus_8388608');
    final userCommentOffset = place(userCommentValue);

    // 2) 构造新的 ExifIFD
    align2();
    final newExifOffset = baseOffset + appendRegion.length;
    final mergedExif = Map<int, _IfdEntry>.from(exifEntries);

    final rawUcOffset = Uint8List(4);
    ByteData.sublistView(rawUcOffset).setUint32(0, userCommentOffset, endian);
    mergedExif[0x9286] = _IfdEntry(0x9286, 7, userCommentValue.length, rawUcOffset);

    appendRegion.add(_serialiseIfd(mergedExif, exifNext, endian));

    // 3) 构造新的 IFD0
    final mergedIfd0 = Map<int, _IfdEntry>.from(ifd0Entries);
    // 注入 ExifOffset 指向 newExifOffset
    final rawExifOffset = Uint8List(4);
    ByteData.sublistView(rawExifOffset).setUint32(0, newExifOffset, endian);
    mergedIfd0[0x8769] = _IfdEntry(0x8769, 4, 1, rawExifOffset);

    // 注入小米 0x8897 = 1 (BYTE)
    final rawXiaomi = Uint8List(4)..[0] = 1;
    mergedIfd0[0x8897] = _IfdEntry(0x8897, 1, 1, rawXiaomi);

    align2();
    final newIfd0Offset = baseOffset + appendRegion.length;
    appendRegion.add(_serialiseIfd(mergedIfd0, nextIfd0, endian));

    final result = BytesBuilder(copy: false);
    // 写头: 前4字节不变，4..8 字节更新为 newIfd0Offset
    final newHeader = Uint8List.fromList(tiff.sublist(0, 8));
    ByteData.sublistView(newHeader).setUint32(4, newIfd0Offset, endian);
    result.add(newHeader);
    result.add(tiff.sublist(8));
    if (tiff.length % 2 != 0) {
      result.addByte(0);
    }
    result.add(appendRegion.takeBytes());

    final finalTiff = result.takeBytes();
    if (finalTiff.length > 65527) {
      // 超过单个 APP1 上限，返回最小安全 Exif
      return _buildMinimalVendorExif();
    }
    return finalTiff;
  }

  static int? _decodePointer(_IfdEntry entry, Endian endian) {
    if (entry.raw.length < 4) return null;
    return ByteData.sublistView(entry.raw).getUint32(0, endian);
  }

  static Uint8List _serialiseIfd(Map<int, _IfdEntry> entries, int nextOffset, Endian endian) {
    final sortedKeys = entries.keys.toList()..sort();
    final size = 2 + sortedKeys.length * 12 + 4;
    final bytes = Uint8List(size);
    final bd = ByteData.sublistView(bytes);

    bd.setUint16(0, sortedKeys.length, endian);
    int pos = 2;
    for (final tag in sortedKeys) {
      final e = entries[tag]!;
      bd.setUint16(pos, e.tag, endian);
      bd.setUint16(pos + 2, e.type, endian);
      bd.setUint32(pos + 4, e.count, endian);
      for (int i = 0; i < 4; i++) {
        bytes[pos + 8 + i] = (i < e.raw.length) ? e.raw[i] : 0;
      }
      pos += 12;
    }
    bd.setUint32(pos, nextOffset, endian);
    return bytes;
  }
}

class _IfdEntry {
  final int tag;
  final int type;
  final int count;
  final Uint8List raw;

  _IfdEntry(this.tag, this.type, this.count, this.raw);
}
