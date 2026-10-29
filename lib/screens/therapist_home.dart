import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';
import 'therapists.dart';

/// لوحة المعالج: تقديم الملف للتوثيق، ثم إدارة المواعيد المتاحة.
class TherapistPanel extends StatefulWidget {
  const TherapistPanel({super.key});
  @override
  State<TherapistPanel> createState() => _TherapistPanelState();
}

class _TherapistPanelState extends State<TherapistPanel> {
  late Future<Map?> f = _load();
  Future<Map?> _load() async {
    try {
      return await Api.get('/therapist/me') as Map;
    } on ApiError catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  void _reload() => setState(() => f = _load());
  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addSlot() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    try {
      await Api.post('/therapist/slots', {'start': dt.toUtc().toIso8601String(), 'minutes': 50});
      _reload();
    } on ApiError catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) => MintTop(
        child: FutureBuilder<Map?>(
          future: f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: C.green));
            if (s.hasError) return ErrorBox('${s.error}', onRetry: _reload);
            final m = s.data;
            if (m == null) return _ApplyForm(onDone: _reload);
            final status = m['status'];
            if (status != 'verified') {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(status == 'rejected' ? Icons.block : Icons.hourglass_top, size: 48, color: C.lotusMid),
                    const SizedBox(height: 12),
                    Text(status == 'rejected' ? 'لم يُقبل طلبك' : 'طلبك قيد المراجعة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('يراجع فريقنا رقم ترخيصك قبل ظهورك للمرضى.', textAlign: TextAlign.center, style: TextStyle(color: C.grey)),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _reload, child: const Text('تحديث الحالة')),
                  ]),
                ),
              );
            }
            final slots = [for (final x in (m['slots'] ?? [])) x as Map];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Avatar('${m['name']}', size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text('${m['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                const Chip(label: Text('موثّق', style: TextStyle(fontSize: 11)), backgroundColor: C.mintSoft, side: BorderSide.none),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Text('مواعيدي المتاحة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton.icon(onPressed: _addSlot, icon: const Icon(Icons.add), label: const Text('إضافة موعد')),
              ]),
              if (slots.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('أضف مواعيد ليتمكن المرضى من حجزك.', style: TextStyle(color: C.grey)))),
              for (final sl in slots)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Text('${fmtTime(DateTime.parse(sl['start']))} • ${sl['minutes']} دقيقة')),
                    if (sl['booked'] == 1) const Chip(label: Text('محجوز', style: TextStyle(fontSize: 11)), backgroundColor: C.lotusSoft, side: BorderSide.none)
                    else IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () async {
                      try { await Api.delete('/therapist/slots/${sl['id']}'); _reload(); } on ApiError catch (e) { _snack(e.message); }
                    }),
                  ]),
                ),
            ]);
          },
        ),
      );
}

class _ApplyForm extends StatefulWidget {
  final VoidCallback onDone;
  const _ApplyForm({required this.onDone});
  @override
  State<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<_ApplyForm> {
  final name = TextEditingController(), title = TextEditingController(), license = TextEditingController(), price = TextEditingController(), topics = TextEditingController(), bio = TextEditingController();
  bool busy = false;
  Widget _f(String l, TextEditingController c, {TextInputType? k, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: k, maxLines: lines, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      );

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      await Api.post('/therapist/apply', {
        'name': name.text.trim(), 'title': title.text.trim(), 'licenseNo': license.text.trim(), 'priceDzd': int.tryParse(price.text.trim()) ?? 0,
        'topics': topics.text.split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), 'languages': ['العربية'], 'bio': bio.text.trim(),
      });
      widget.onDone();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('انضم كمعالج', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('نراجع رقم ترخيصك قبل ظهورك للمرضى.', style: TextStyle(color: C.grey)),
        const SizedBox(height: 16),
        _f('الاسم الكامل', name),
        _f('التخصص (مثال: أخصائي نفسي)', title),
        _f('رقم الترخيص المهني', license),
        _f('سعر الجلسة بالدينار الجزائري', price, k: TextInputType.number),
        _f('المجالات (افصل بفاصلة)', topics),
        _f('نبذة قصيرة', bio, lines: 3),
        ElevatedButton(onPressed: busy ? null : _send, child: Text(busy ? 'جارٍ الإرسال…' : 'أرسل للمراجعة')),
      ]);
}
