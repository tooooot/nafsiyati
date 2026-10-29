import 'package:flutter/material.dart';
import '../theme.dart';
import 'therapists.dart';
import 'call.dart';

/// الغلاف: شريط سفلي ثابت في كل الصفحات (ملاحظة المالك في المحادثة الأصلية).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 1;
  static const _titles = ['الرئيسية', 'المعالجون', 'جلساتي', 'حسابي'];
  Widget _body() {
    if (tab == 1) return const TherapistsScreen();
    if (tab == 2) return const DemoCallEntry();
    return Center(child: Text('${_titles[tab]} — قريباً', style: const TextStyle(color: C.grey)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _body()),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          indicatorColor: C.mintSoft,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'المعالجون'),
            NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'جلساتي'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
          ],
        ),
      );
}
