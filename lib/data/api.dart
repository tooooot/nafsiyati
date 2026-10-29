import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = 'https://nafsiyati.wardyat.net/api';

class ApiError implements Exception {
  final int code;
  final String message;
  ApiError(this.code, this.message);
  @override
  String toString() => message;
}

/// عميل الواجهة البرمجية: يحمل توكن الجلسة (من wardyat-core) ويضيفه لكل طلب.
class Api {
  static String? token;
  static String? role; // 'patient' | 'therapist' (اختيار المستخدم عند الترحيب)
  static bool quizDone = false;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    role = p.getString('role');
    quizDone = p.getBool('quiz') ?? false;
  }

  static Future<void> markQuizDone() async {
    quizDone = true;
    await (await SharedPreferences.getInstance()).setBool('quiz', true);
    try {
      await post('/me/quiz');
    } catch (_) {}
  }

  static Future<void> save({String? newToken, String? newRole}) async {
    final p = await SharedPreferences.getInstance();
    if (newToken != null) {
      token = newToken;
      await p.setString('token', newToken);
    }
    if (newRole != null) {
      role = newRole;
      await p.setString('role', newRole);
    }
  }

  static Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    token = null;
    role = null;
    await p.remove('token');
    await p.remove('role');
    await p.remove('quiz');
    quizDone = false;
  }

  static Future<dynamic> _req(String m, String path, [Object? body]) async {
    final h = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    final u = Uri.parse('$apiBase$path');
    final enc = body == null ? null : jsonEncode(body);
    final http.Response r;
    try {
      r = switch (m) {
        'POST' => await http.post(u, headers: h, body: enc),
        'PUT' => await http.put(u, headers: h, body: enc),
        'DELETE' => await http.delete(u, headers: h),
        _ => await http.get(u, headers: h),
      };
    } catch (_) {
      throw ApiError(0, 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.');
    }
    final d = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) throw ApiError(r.statusCode, d is Map ? '${d['error'] ?? 'خطأ'}' : 'خطأ');
    return d;
  }

  static Future<dynamic> get(String p) => _req('GET', p);
  static Future<dynamic> post(String p, [Object? b]) => _req('POST', p, b ?? {});
  static Future<dynamic> put(String p, Object b) => _req('PUT', p, b);
  static Future<dynamic> delete(String p) => _req('DELETE', p);
}
