import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../theme.dart';
import 'therapists.dart';

/// ملف المعالج + اختيار الموعد (Figma: Profile Psy / Book Consultation).
class ProfileScreen extends StatefulWidget {
  final Therapist t;
  const ProfileScreen(this.t, {super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? slot;
  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(title: const Text('ملف المعالج'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Avatar(t.name, size: 72),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(t.title, style: const TextStyle(color: C.grey)),
            Text('اللغات: ${t.languages.join('، ')}', style: const TextStyle(fontSize: 12, color: C.grey)),
          ])),
        ]),
        const SizedBox(height: 16),
        Text(t.bio),
        const SizedBox(height: 20),
        const Text('اختر موعداً', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in t.slots)
            ChoiceChip(label: Text(s), selected: slot == s, selectedColor: C.mintSoft, onSelected: (_) => setState(() => slot = s)),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: C.green),
            const SizedBox(width: 8),
            const Expanded(child: Text('جلسة فيديو داخل التطبيق، لا تُسجَّل ولا تُخزَّن.', style: TextStyle(fontSize: 12, color: C.grey))),
          ]),
        ),
        const SizedBox(height: 16),
        Text('${t.priceDzd} دج / الجلسة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: slot == null ? null : () => showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('تم طلب الحجز'),
            content: Text('الموعد: $slot\nالدفع عند العيادة/يدوياً في هذه النسخة التجريبية.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
          )),
          child: const Text('احجز الجلسة'),
        ),
      ]),
    );
  }
}
