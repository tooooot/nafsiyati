import 'dart:convert';
import 'package:http/http.dart' as http;

const apiBase = 'https://nafsiyati.wardyat.net/api';

class VideoToken {
  final String url, token;
  VideoToken(this.url, this.token);
}

/// يطلب توكن غرفة الفيديو من الخادم (غرف التجربة فقط حالياً).
Future<VideoToken> fetchVideoToken(String room, String name) async {
  final r = await http.post(Uri.parse('$apiBase/video/token'),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'room': room, 'name': name}));
  if (r.statusCode != 200) {
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['error'] ?? 'تعذّر الاتصال (${r.statusCode})');
  }
  final d = jsonDecode(utf8.decode(r.bodyBytes));
  return VideoToken(d['url'], d['token']);
}
