import 'package:flutter/material.dart';
import '../theme.dart';
import 'quiz.dart';
import 'home.dart';

/// الدخول بجوجل وآبل فقط (قرار المالك). الربط الفعلي بـ wardyat-core في مرحلة لاحقة.
class LoginScreen extends StatelessWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  void _done(BuildContext c) => Navigator.pushAndRemoveUntil(
      c, MaterialPageRoute(builder: (_) => role == 'patient' ? const QuizScreen() : const HomeShell()), (r) => false);

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
                const Spacer(),
                ElevatedButton(onPressed: () => _done(context), child: const Text('المتابعة بحساب Google')),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () => _done(context),
                  child: const Text('المتابعة بحساب Apple'),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      );
}
