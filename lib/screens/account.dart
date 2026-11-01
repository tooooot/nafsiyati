import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/api.dart';
import '../theme.dart';
import 'staff_screens.dart';
import 'wallet.dart';
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
              if (((u?['perms'] as List?) ?? const []).isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: ListTile(leading: const Icon(Icons.dashboard_customize_outlined), title: const Text('لوحات العمل'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffHub(u!['perms'] as List)))),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('محفظتي'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('سياسة الخصوصية'), trailing: const Icon(Icons.chevron_left), onTap: () => launchUrl(Uri.parse('https://nafsiyati.wardyat.net/privacy/'), mode: LaunchMode.externalApplication)),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('يحذف حسابك وبياناتك نهائياً'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('حذف الحساب نهائياً؟'),
                        content: const Text('سيُحذف حسابك وبياناتك وتُلغى مواعيدك القادمة. لا يمكن التراجع عن ذلك.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف نهائياً', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await Api.delete('/me');
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الحذف: $e')));
                      return;
                    }
                    await Api.signOut();
                    if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
                  },
                ),
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
