import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme.dart';

/// الرئيسية للمريض: هادئة ورسمية بطابع المؤسسات الطبية. موعدك القادم، كيف تستعد، معلومات موثوقة، خصوصيتك.
/// النصوص التوعوية عامة وغير تشخيصية، وتُراجَع من معالج مرخّص قبل الإطلاق العام.
class PatientHome extends StatelessWidget {
  final VoidCallback onBook;
  const PatientHome({super.key, required this.onBook});

  static const _articles = [
    ('متى أطلب مساعدة مختص؟', 'إذا استمر القلق أو الحزن أو اضطراب النوم أسابيع وأثّر في عملك أو علاقاتك أو يومك، فاستشارة مختص خطوة سليمة ومبكرة، وليست علامة ضعف. كلما بدأت مبكراً كان التحسن أيسر.'),
    ('ماذا يحدث في الجلسة الأولى؟', 'جلسة تعارف: يسألك المعالج عمّا يشغلك وتاريخك الصحي وما تتمنى أن يتغير، ثم يتفقان على خطة. لا يُطلب منك قول ما لا ترتاح لقوله، ولك أن تتوقف متى شئت.'),
    ('النوم والصحة النفسية', 'النوم المنتظم يخفف التوتر ويحسّن المزاج. حاول تثبيت موعد النوم والاستيقاظ، وقلّل الشاشات والمنبهات مساءً. إن استمر الأرق طويلاً فاذكره لمعالجك.'),
    ('كيف أتحدث عمّا أشعر به؟', 'ابدأ بجمل بسيطة: «منذ فترة أشعر بـ…». يكفي أن تصف ما تلاحظه في جسدك ومزاجك وتفكيرك دون تحليل. المعالج يساعدك على ترتيب الباقي.'),
    ('الجلسة بالفيديو: كيف أستعد؟', 'اختر مكاناً هادئاً ومغلقاً، واتصل بشبكة مستقرة، وجرّب الكاميرا والميكروفون قبل الموعد بدقائق، ولا تحتاج إلى برنامج إضافي: الجلسة داخل التطبيق.'),
  ];

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
        FutureBuilder(
          future: Api.get('/me'),
          builder: (c, s) {
            final n = ((s.data is Map ? (s.data as Map)['user'] : null) as Map?)?['name'] ?? '';
            return Text(n.toString().isEmpty ? 'أهلاً بك' : 'أهلاً، ${n.toString().split(' ').first}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink));
          },
        ),
        const SizedBox(height: 4),
        const Text('نرافقك بخصوصية واحترام، مع معالجين موثّقين.', style: TextStyle(color: C.grey)),
        const SizedBox(height: 18),
        FutureBuilder(
          future: Api.get('/appointments'),
          builder: (c, s) {
            final list = s.data is List ? [for (final j in s.data as List) Appointment.fromJson(j)] : <Appointment>[];
            final next = list.where((a) => a.status == 'booked' && a.end.isAfter(DateTime.now().toUtc())).toList()..sort((a, b) => a.start.compareTo(b.start));
            final a = next.isEmpty ? null : next.first;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: C.lotusDark, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a == null ? 'لا موعد قادم' : 'موعدك القادم', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(a == null ? 'احجز جلستك الأولى مع معالج موثّق' : '${fmtTime(a.start)}  •  ${a.therapist ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: onBook, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.lotusDark, minimumSize: const Size(160, 44)), child: Text(a == null ? 'تصفّح المعالجين' : 'حجز موعد آخر')),
              ]),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text('كيف تسير الخدمة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          for (final s in const [(Icons.search, 'اختر معالجاً موثّقاً'), (Icons.event_available_outlined, 'احجز موعداً'), (Icons.videocam_outlined, 'جلسة فيديو خاصة')])
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: Column(children: [Icon(s.$1, color: C.green), const SizedBox(height: 6), Text(s.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
              ),
            ),
        ]),
        const SizedBox(height: 22),
        const Text('معلومات تهمّك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final a in _articles)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(a.$2, style: const TextStyle(color: C.grey, height: 1.7))],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.mintSoft.withOpacity(.45), borderRadius: BorderRadius.circular(14)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, color: C.lotusDark),
            SizedBox(width: 12),
            Expanded(child: Text('خصوصيتك أولاً: جلساتك لا تُسجَّل، وملاحظات المعالج سريّة، وفريق التسويق والمالية لا يرون بياناتك الصحية.', style: TextStyle(height: 1.7, fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.shade200)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.local_hospital_outlined, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('هذه الخدمة ليست للحالات الطارئة. إن كنت أو كان أحد من حولك في خطر فوري فاتصل بجهة الطوارئ في بلدك أو توجّه لأقرب مستشفى.', style: TextStyle(height: 1.7, fontSize: 13))),
          ]),
        ),
      ]);
}
