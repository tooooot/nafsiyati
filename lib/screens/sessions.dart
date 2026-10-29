import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';
import 'call.dart';
import 'therapists.dart';

/// جلساتي: مواعيد المريض أو المعالج مع زر الدخول (يفتح قبل البدء بعشر دقائق).
class SessionsScreen extends StatefulWidget {
  final bool asTherapist;
  const SessionsScreen({super.key, this.asTherapist = false});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late Future<List<Appointment>> f = _load();
  Future<List<Appointment>> _load() async => [for (final j in await Api.get('/appointments')) Appointment.fromJson(j)];
  Future<void> _refresh() async {
    setState(() => f = _load());
    await f.catchError((_) => <Appointment>[]);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join(Appointment a) async {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(connect: () async {
        final r = await Api.post('/appointments/${a.id}/video-token');
        return (url: '${r['url']}', token: '${r['token']}');
      })));
    } on ApiError catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _cancel(Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(title: const Text('إلغاء الموعد؟'), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء الموعد')),
      ]),
    );
    if (ok != true) return;
    try {
      await Api.post('/appointments/${a.id}/cancel');
      await _refresh();
    } on ApiError catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) => MintTop(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Appointment>>(
            future: f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: C.green));
              if (s.hasError) return ErrorBox('${s.error}', onRetry: _refresh);
              final nowU = DateTime.now().toUtc();
              // المنتهية (بعد النهاية بعشر دقائق) لا تُعرض؛ المتاحة للدخول أولاً ثم بحسب الوقت
              final list = s.data!.where((a) => a.status == 'booked' && nowU.isBefore(a.end.add(const Duration(minutes: 10)))).toList()
                ..sort((x, y) => x.joinable == y.joinable ? x.start.compareTo(y.start) : (x.joinable ? -1 : 1));
              return ListView(padding: const EdgeInsets.all(16), children: [
                const Text('جلساتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('لا جلسات قادمة.', style: TextStyle(color: C.grey)))),
                for (final a in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(widget.asTherapist ? (a.patient ?? 'مريض') : (a.therapist ?? ''), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        if (a.joinable) const Chip(label: Text('متاحة الآن', style: TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: C.green, side: BorderSide.none, visualDensity: VisualDensity.compact),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.event, size: 16, color: C.grey), const SizedBox(width: 6), Text('${fmtTime(a.start)} • ${a.minutes} دقيقة', style: const TextStyle(color: C.grey))]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(onPressed: a.joinable ? () => _join(a) : null, icon: const Icon(Icons.videocam), label: Text(a.joinable ? 'ادخل الجلسة' : 'تُفتح قبل الموعد بـ10 دقائق'))),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => _cancel(a), child: const Text('إلغاء')),
                      ]),
                    ]),
                  ),
              ]);
            },
          ),
        ),
      );
}
