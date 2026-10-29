import 'dart:math';
import 'package:web/web.dart' as web;

/// يقرأ ما أعاده Google/Apple في الجزء بعد # ثم يمسحه من العنوان قبل تشغيل Flutter
/// (وإلا فسّره كمسار ابتدائي).
Map<String, String> takeAuthFragment() {
  final h = web.window.location.hash;
  if (h.length < 2) return {};
  final out = <String, String>{};
  try {
    out.addAll(Uri.splitQueryString(h.substring(1)));
  } catch (_) {}
  if (out.containsKey('id_token') || out.containsKey('apple_id_token') || out.containsKey('state')) {
    web.window.history.replaceState(null, '', web.window.location.pathname + web.window.location.search);
    return out;
  }
  return {};
}

void goTo(String url) => web.window.location.href = url;

String randomNonce() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}
