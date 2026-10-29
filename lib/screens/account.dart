import 'package:flutter/material.dart';
import '../data/api.dart';
import '../theme.dart';
import 'admin.dart';
import 'therapists.dart';
import 'welcome.dart';

/// حسابي: البروفايل والخروج (البروفايل منفصل عن الإعدادات كما في معيار التطبيق الحديث).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) => MintTop(
        child: FutureBuilder(
          future: Api.get('/me'),
          builder: (c, s) {
            final u = (s.data is Map ? (s.data as Map)['user'] : null) as Map?;
            return ListView(padding: const EdgeInsets.all(16), children: [
              const SizedBox(height: 12),
              Center(child: Avatar('${u?['name'] ?? ''}', size: 84)),
              const SizedBox(height: 10),
              Center(child: Text('${u?['name'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              Center(child: Text('${u?['email'] ?? ''}', style: const TextStyle(color: C.grey, fontSize: 13))),
              const SizedBox(height: 24),
              if (u?['isAdmin'] == true) ...[
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('إدارة المعالجين'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('سياسة الخصوصية'), trailing: const Icon(Icons.chevron_left), onTap: () {}),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await Api.signOut();
                  if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
                },
                child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ),
            ]);
          },
        ),
      );
}
