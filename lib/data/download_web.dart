import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// ينزّل نصاً كملف عبر المتصفح (CSV بترميز UTF-8).
bool saveTextFile(String name, String text) {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
