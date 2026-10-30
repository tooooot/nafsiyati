import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/api.dart';
import 'data/oauth.dart';
import 'screens/home.dart';
import 'screens/quiz.dart';
import 'screens/welcome.dart';
import 'theme.dart';

/// دخول المراجعة بتوكن جلسة عبر ?dev=…&role=… (يُفعَّل ببناء المراجعة فقط، ويُزال عند تفعيل الدخول الحقيقي).
const devLogin = bool.fromEnvironment('DEV_LOGIN');

Map<String, String> authFragment = {};
String? loginError; // آخر خطأ دخول، يُعرض في شاشة الدخول

void main() {
  authFragment = takeAuthFragment(); // قبل runApp: يمسح # من العنوان
  runApp(const NafsiyatiApp());
}

class NafsiyatiApp extends StatelessWidget {
  const NafsiyatiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'صحتي النفسية',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Boot(),
      );
}

/// يقرّر الشاشة الأولى: جلسة محفوظة صالحة ← التطبيق، وإلا الترحيب.
class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  late final Future<Widget> f = _decide();
  Future<Widget> _decide() async {
    await Api.load();
    if (devLogin) {
      final q = Uri.base.queryParameters;
      if (q['dev'] != null) await Api.save(newToken: q['dev'], newRole: q['role'] == 'therapist' ? 'therapist' : 'patient');
    }
    final f = authFragment;
    if (f['id_token'] != null || f['apple_id_token'] != null) {
      try {
        final google = f['id_token'] != null;
        final r = await Api.post(google ? '/auth/google' : '/auth/apple', {'id_token': google ? f['id_token'] : f['apple_id_token']});
        await Api.save(newToken: r['token'] as String, newRole: f['state'] == 'therapist' ? 'therapist' : 'patient');
      } on ApiError catch (e) {
        loginError = e.message;
      }
      authFragment = {};
    }
    if (Api.token == null) return const WelcomeScreen();
    try {
      await Api.get('/me');
    } on ApiError catch (e) {
      if (e.code == 401) {
        await Api.signOut();
        return const WelcomeScreen();
      }
    }
    if (Api.role == 'therapist') return const HomeShell(therapist: true);
    return Api.quizDone ? const HomeShell() : const QuizScreen();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: f,
        builder: (c, s) => s.hasData ? s.data! : const Scaffold(body: Center(child: CircularProgressIndicator(color: C.green))),
      );
}
