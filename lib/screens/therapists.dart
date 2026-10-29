import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';
import 'profile.dart';

class TherapistsScreen extends StatefulWidget {
  const TherapistsScreen({super.key});
  @override
  State<TherapistsScreen> createState() => _TherapistsScreenState();
}

class _TherapistsScreenState extends State<TherapistsScreen> {
  late Future<List<Therapist>> f = _load();
  Future<List<Therapist>> _load() async => [for (final j in await Api.get('/therapists')) Therapist.fromJson(j)];
  Future<void> _refresh() async {
    setState(() => f = _load());
    await f.catchError((_) => <Therapist>[]);
  }

  @override
  Widget build(BuildContext context) => MintTop(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Therapist>>(
            future: f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: C.green));
              if (s.hasError) return ErrorBox('${s.error}', onRetry: _refresh);
              final list = s.data!;
              return ListView(padding: const EdgeInsets.all(16), children: [
                const Text('المعالجون', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('الأقرب موعداً لك', style: TextStyle(color: C.grey)),
                const SizedBox(height: 16),
                if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('لا يوجد معالجون متاحون حالياً.', style: TextStyle(color: C.grey)))),
                for (final t in list) _Card(t, onBooked: _refresh),
              ]);
            },
          ),
        ),
      );
}

class ErrorBox extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const ErrorBox(this.msg, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: C.grey)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 56});
  @override
  Widget build(BuildContext context) {
    final clean = name.replaceAll(RegExp(r'^(د\.|أ\.)\s*'), '');
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: C.lotusSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(clean.isEmpty ? '؟' : clean.characters.first, style: TextStyle(fontSize: size * .4, fontWeight: FontWeight.w800, color: C.lotusDark)),
    );
  }
}

class _Card extends StatelessWidget {
  final Therapist t;
  final Future<void> Function() onBooked;
  const _Card(this.t, {required this.onBooked});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(t.name),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(t.title, style: const TextStyle(color: C.grey, fontSize: 13)),
              Text('${t.priceDzd} دج / الجلسة', style: const TextStyle(fontSize: 12, color: C.green, fontWeight: FontWeight.w700)),
            ])),
          ]),
          if (t.bio.isNotEmpty) ...[const SizedBox(height: 10), Text(t.bio, style: const TextStyle(color: C.grey, fontSize: 13))],
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [for (final x in t.topics) Chip(label: Text(x, style: const TextStyle(fontSize: 11)), backgroundColor: C.mintSoft, side: BorderSide.none, visualDensity: VisualDensity.compact)]),
          const SizedBox(height: 6),
          Text(t.slots.isEmpty ? 'لا مواعيد متاحة حالياً' : 'أقرب موعد: ${fmtTime(t.slots.first.start)}', style: const TextStyle(fontSize: 12, color: C.grey)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(t.id)));
              await onBooked();
            },
            child: const Text('عرض الملف'),
          ),
        ]),
      );
}
