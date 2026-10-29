import 'package:flutter/material.dart';
import '../data/oauth.dart';
import '../main.dart' show loginError;
import '../theme.dart';

const _site = 'https://nafsiyati.wardyat.net';
const _googleClient = '37245051104-4305md0d01paj5hb12pnmeaakvjueeg0.apps.googleusercontent.com';
const _appleService = 'net.wardyat.nafsiyati.web';

/// الدخول بجوجل وآبل فقط (قرار المالك)، عبر إعادة توجيه ثم يتحقق الخادم من الرمز لدى wardyat-core.
class LoginScreen extends StatelessWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  void _google() => goTo('https://accounts.google.com/o/oauth2/v2/auth?${Uri(queryParameters: {
        'client_id': _googleClient,
        'redirect_uri': '$_site/',
        'response_type': 'id_token',
        'scope': 'openid email profile',
        'nonce': randomNonce(),
        'state': role,
        'prompt': 'select_account',
      }).query}');

  void _apple() => goTo('https://appleid.apple.com/auth/authorize?${Uri(queryParameters: {
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
                ElevatedButton(onPressed: _google, child: const Text('المتابعة بحساب Google')),
                const SizedBox(height: 12),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: _apple, child: const Text('المتابعة بحساب Apple')),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      );
}
