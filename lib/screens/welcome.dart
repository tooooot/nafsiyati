import 'package:flutter/material.dart';
import '../main.dart' show loginError;
import '../theme.dart';
import 'login.dart';

/// شاشة الترحيب + اختيار الدور (طبيب / مريض) — Onboarding 1 في Figma.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String role = 'patient';
  @override
  Widget build(BuildContext context) => Scaffold(
        body: MintTop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const Spacer(flex: 2),
                Image.asset('assets/logo.png', width: 150),
                const SizedBox(height: 12),
                const Text('صحتي النفسية', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: C.lotusDark)),
                const SizedBox(height: 16),
                const Text('خطوتك الأولى نحو عقل أهدأ', style: TextStyle(color: C.grey, fontSize: 15)),
                if (loginError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('تعذّر الدخول: $loginError', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
                const Spacer(flex: 3),
                _RoleSwitch(role: role, onChanged: (r) => setState(() => role = r)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: role))),
                  child: const Text('ابدأ'),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      );
}

class _RoleSwitch extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;
  const _RoleSwitch({required this.role, required this.onChanged});
  Widget _tab(String id, String label) => Expanded(
        child: GestureDetector(
          onTap: () => onChanged(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(color: role == id ? C.green : Colors.transparent, borderRadius: BorderRadius.circular(100)),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: role == id ? Colors.white : C.green)),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
        child: Row(children: [_tab('patient', 'مريض'), _tab('therapist', 'معالج')]),
      );
}
