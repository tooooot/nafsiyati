import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';
import 'notes.dart';
import 'staff_screens.dart';
import 'wallet.dart';

/// ختام الجلسة. المريض: تقييم (يراه المخوَّلون بالإدارة فقط، لا المعالج) + حالة الدفع. المعالج: ملاحظاته السرية.
class EndSessionScreen extends StatefulWidget {
  final Appointment a;
  final bool asTherapist;
  const EndSessionScreen(this.a, {super.key, required this.asTherapist});
  @override
  State<EndSessionScreen> createState() => _EndSessionScreenState();
}

class _EndSessionScreenState extends State<EndSessionScreen> {
  int stars = 0;
  bool busy = false, sent = false;
  final note = TextEditingController();

  Future<void> _send() async {
    if (stars == 0) return toast(context, 'اختر عدد النجوم');
    setState(() => busy = true);
    final ok = await act(context, () => Api.post('/appointments/${widget.a.id}/rating', {'stars': stars, 'note': note.text.trim()}));
    if (!mounted) return;
    setState(() { busy = false; sent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a, who = widget.asTherapist ? (a.patient ?? 'المريض') : (a.therapist ?? 'المعالج');
    return PageShell(
      'انتهت الجلسة',
      ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.check_circle, color: C.green, size: 64),
        const SizedBox(height: 12),
        Center(child: Text('انتهت جلستك مع $who', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
        const SizedBox(height: 4),
        Center(child: Text('${fmtTime(a.start)} • ${a.minutes} دقيقة', style: const TextStyle(color: C.grey))),
        const SizedBox(height: 24),
        if (widget.asTherapist) ...[
          const Text('الخطوة التالية: دوّن ملاحظاتك السرية عن الجلسة. لا يراها المريض.', style: TextStyle(color: C.grey)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotesScreen(a.id, a.patient ?? 'مريض'))), child: const Text('كتابة الملاحظات')),
          const SizedBox(height: 8),
          const Text('تظهر الجلسة الآن في «الجلسات السابقة»، ويُحتسب مستحقك بعد تأكيد الدفع من الإدارة.', style: TextStyle(color: C.grey, fontSize: 12)),
        ] else ...[
          const Text('كيف كانت جلستك؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('تقييمك يصل إلى الإدارة فقط ولا يراه المعالج.', style: TextStyle(color: C.grey, fontSize: 12)),
          const SizedBox(height: 10),
          if (sent) const Center(child: Text('شكراً، وصل تقييمك.', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)))
          else ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++) IconButton(iconSize: 38, onPressed: () => setState(() => stars = i), icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: Colors.orange)),
            ]),
            TextField(controller: note, maxLines: 3, maxLength: 500, decoration: const InputDecoration(hintText: 'ملاحظة اختيارية', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: busy ? null : _send, child: Text(busy ? 'جارٍ الإرسال…' : 'إرسال التقييم')),
          ],
          const SizedBox(height: 24),
          box(child: Row(children: [
            const Icon(Icons.receipt_long, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text('رسوم الجلسة: ${dzd(a.priceDzd)}\nالدفع يُؤكَّد يدوياً من الإدارة، وتجد حالته في محفظتي.', style: const TextStyle(fontSize: 13))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())), child: const Text('محفظتي')),
          ])),
        ],
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
      ]),
    );
  }
}
