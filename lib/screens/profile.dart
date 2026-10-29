import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';
import 'therapists.dart';

/// ملف المعالج + اختيار الموعد والحجز.
class ProfileScreen extends StatefulWidget {
  final String id;
  const ProfileScreen(this.id, {super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Therapist> f = _load();
  String? slotId;
  bool busy = false;
  Future<Therapist> _load() async => Therapist.fromJson(await Api.get('/therapists/${widget.id}'));

  Future<void> _book(Therapist t) async {
    setState(() => busy = true);
    try {
      final r = await Api.post('/appointments', {'slotId': slotId});
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم حجز الموعد'),
          content: Text('${t.name}\n${fmtTime(DateTime.parse(r['start']))}\nالدفع عند الجلسة في هذه النسخة التجريبية.\nستجد الموعد في «جلساتي».'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() {
        slotId = null;
        f = _load();
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملف المعالج'), backgroundColor: Colors.transparent),
        body: FutureBuilder<Therapist>(
          future: f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: C.green));
            if (s.hasError) return ErrorBox('${s.error}', onRetry: () => setState(() => f = _load()));
            final t = s.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Avatar(t.name, size: 72),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(t.title, style: const TextStyle(color: C.grey)),
                  if (t.languages.isNotEmpty) Text('اللغات: ${t.languages.join('، ')}', style: const TextStyle(fontSize: 12, color: C.grey)),
                ])),
              ]),
              if (t.bio.isNotEmpty) ...[const SizedBox(height: 16), Text(t.bio)],
              const SizedBox(height: 20),
              const Text('اختر موعداً', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              if (t.slots.isEmpty) const Text('لا مواعيد متاحة حالياً.', style: TextStyle(color: C.grey)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final sl in t.slots)
                  ChoiceChip(label: Text(fmtTime(sl.start)), selected: slotId == sl.id, selectedColor: C.mintSoft, onSelected: (_) => setState(() => slotId = sl.id)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.verified_user_outlined, color: C.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('جلسة فيديو داخل التطبيق، لا تُسجَّل ولا تُخزَّن.', style: TextStyle(fontSize: 12, color: C.grey))),
                ]),
              ),
              const SizedBox(height: 16),
              Text('${t.priceDzd} دج / الجلسة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: slotId == null || busy ? null : () => _book(t), child: Text(busy ? 'جارٍ الحجز…' : 'احجز الجلسة')),
            ]);
          },
        ),
      );
}
