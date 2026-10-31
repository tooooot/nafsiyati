import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../data/api.dart';
import '../data/oauth.dart';
import '../main.dart' show Boot, loginError;
import '../theme.dart';

const _site = 'https://nafsiyati.wardyat.net';
const _googleClient = '37245051104-4305md0d01paj5hb12pnmeaakvjueeg0.apps.googleusercontent.com';
const _appleService = 'net.wardyat.nafsiyati.web';

/// الدخول بجوجل وآبل فقط (قرار المالك)، عبر إعادة توجيه ثم يتحقق الخادم من الرمز لدى wardyat-core.
class LoginScreen extends StatelessWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  bool get _iosApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _androidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// التطبيق الأصلي (أندرويد): نافذة Google الأصلية ثم الرمز للخادم. الويب: إعادة توجيه.
  Future<void> _google(BuildContext context) async {
    if (kIsWeb) return _googleWeb();
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _googleClient);
      final acc = await GoogleSignIn.instance.authenticate();
      final tok = acc.authentication.idToken;
      if (tok == null) throw ApiError(0, 'لم يصل رمز الدخول من Google');
      final r = await Api.post('/auth/google', {'id_token': tok});
      await Api.save(newToken: r['token'] as String, newRole: role);
      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Boot()), (r) => false);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الدخول: ${e is ApiError ? e.message : e}')));
    }
  }

  void _googleWeb() => goTo('https://accounts.google.com/o/oauth2/v2/auth?${Uri(queryParameters: {
        'client_id': _googleClient,
        'redirect_uri': '$_site/',
        'response_type': 'id_token',
        'scope': 'openid email profile',
        'nonce': randomNonce(),
        'state': role,
        'prompt': 'select_account',
      }).query}');

  /// iOS الأصلي: نافذة Apple الأصلية ثم الرمز للخادم (الهوية = معرّف الحزمة). الويب: إعادة توجيه.
  Future<void> _apple(BuildContext context) async {
    if (kIsWeb) return _appleWeb();
    try {
      final c = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);
      final tok = c.identityToken;
      if (tok == null) throw ApiError(0, 'لم يصل رمز الدخول من Apple');
      final r = await Api.post('/auth/apple', {'id_token': tok});
      await Api.save(newToken: r['token'] as String, newRole: role);
      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Boot()), (r) => false);
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException && e.code == AuthorizationErrorCode.canceled) return;
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الدخول: ${e is ApiError ? e.message : e}')));
    }
  }

  void _appleWeb() => goTo('https://appleid.apple.com/auth/authorize?${Uri(queryParameters: {
        'client_id': _appleService,
        'redirect_uri': '$_site/api/auth/apple/callback',
        'response_type': 'code id_token',
        'response_mode': 'form_post',
        'scope': 'name email',
        'state': role,
      }).query}');

  @override
  Widget build(BuildContext context) => Scaffold(
        body: MintTop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))]),
                const Spacer(),
                Image.asset('assets/logo.png', width: 110),
                const SizedBox(height: 16),
                Text(role == 'patient' ? 'سجّل دخولك كمريض' : 'سجّل دخولك كمعالج', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('خصوصيتك محفوظة. لا نشارك بياناتك مع أحد.', style: TextStyle(color: C.grey), textAlign: TextAlign.center),
                if (loginError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(loginError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
                const Spacer(),
                if (!_iosApp) ElevatedButton(onPressed: () => _google(context), child: const Text('المتابعة بحساب Google')),
                if (!_androidApp) ...[
                if (!_iosApp) const SizedBox(height: 12),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: () => _apple(context), child: const Text('المتابعة بحساب Apple')),
                ],
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      );
}
