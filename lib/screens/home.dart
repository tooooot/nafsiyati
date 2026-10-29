import 'package:flutter/material.dart';
import '../theme.dart';
import 'account.dart';
import 'sessions.dart';
import 'therapist_home.dart';
import 'therapists.dart';

/// الغلاف: شريط سفلي ثابت في كل الصفحات. التبويبات حسب الدور.
class HomeShell extends StatefulWidget {
  final bool therapist;
  const HomeShell({super.key, this.therapist = false});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0, rev = 0; // rev: يُعيد تحميل التبويب عند فتحه ليظهر الحجز الجديد
  @override
  Widget build(BuildContext context) {
    final t = widget.therapist;
    final pages = <Widget>[
      t ? const TherapistPanel() : const TherapistsScreen(),
      SessionsScreen(asTherapist: t),
      const AccountScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: KeyedSubtree(key: ValueKey('$tab-$rev'), child: pages[tab])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        indicatorColor: C.mintSoft,
        onDestinationSelected: (v) => setState(() { tab = v; rev++; }),
        destinations: [
          NavigationDestination(icon: Icon(t ? Icons.calendar_month_outlined : Icons.people_outline), label: t ? 'مواعيدي' : 'المعالجون'),
          const NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'جلساتي'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}
