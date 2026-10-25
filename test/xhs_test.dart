import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Test XHS redirect and parse', () async {
    final client = http.Client();
    final url = 'https://xhslink.cn/o/4F6MsGjCECL';
    String current = url;
    final cookies = <String, String>{};

    for (int i = 0; i < 10; i++) {
      final req = http.Request('GET', Uri.parse(current))
        ..followRedirects = false
        ..headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      if (cookies.isNotEmpty) {
        req.headers['Cookie'] = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
      final resp = await client.send(req);
      final rawSet = resp.headers['set-cookie'];
      if (rawSet != null) {
        for (final item in rawSet.split(',')) {
          final part = item.split(';')[0].trim();
          final eq = part.indexOf('=');
          if (eq > 0) {
            cookies[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
          }
        }
      }
      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        final loc = resp.headers['location'];
        if (loc == null) break;
        current = loc.startsWith('http') ? loc : Uri.parse(current).resolve(loc).toString();
      } else {
        break;
      }
    }
    print('Final URL: $current');
    print('Cookies: $cookies');

    final pageResp = await http.get(Uri.parse(current), headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    });
    print('Page status: ${pageResp.statusCode}');
    final m = RegExp(r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\})\s*</script>', dotAll: true).firstMatch(pageResp.body);
    print('Has INITIAL_STATE: ${m != null}');
    if (m != null) {
      final jsonStr = m.group(1)!.trim().replaceAll(':undefined', ':null');
      final state = json.decode(jsonStr) as Map<String, dynamic>;
      final noteMap = (state['note']?['noteDetailMap'] as Map<String, dynamic>?) ?? {};
      print('Note IDs in map: ${noteMap.keys.toList()}');
      if (noteMap.isNotEmpty) {
        final firstId = noteMap.keys.first;
        final note = noteMap[firstId]?['note'];
        print('Note title: ${note?['title']}');
        print('Note desc: ${note?['desc']?.toString().substring(0, 30)}');
        print('Note type: ${note?['type']}');
        print('Video: ${note?['video'] != null}');
        print('Images count: ${(note?['imageList'] as List?)?.length}');
      }
    }
  });
}
