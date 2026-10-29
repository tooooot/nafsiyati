import 'package:flutter/material.dart';
import '../theme.dart';
import 'staff_screens.dart';

/// محفظتي: ما عليّ دفعه وسجلّ جلساتي وخصوماتي.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
        'محفظتي',
        Loader('/wallet', (c, d, _) {
          final items = (d['items'] as List).cast<Map>();
          return ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [stat('مستحق الدفع', dzd(d['due']), color: (d['due'] as int) > 0 ? Colors.orange : C.green)]),
            const Padding(padding: EdgeInsets.all(8), child: Text('الدفع في هذه النسخة يُؤكَّد يدوياً من الإدارة بعد استلامه (نقداً أو بريدي موب).', style: TextStyle(color: C.grey, fontSize: 12))),
            sectionTitle('سجل الجلسات'),
            if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا جلسات بعد.', style: TextStyle(color: C.grey)))),
            for (final a in items)
              box(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['therapist'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(day(a['start']), style: const TextStyle(color: C.grey, fontSize: 12)),
                      if (a['voucher'] != null) Text('قسيمة ${a['voucher']}: وفّرت ${dzd(a['discountDzd'])}', style: const TextStyle(color: C.green, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(dzd(a['priceDzd']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(a['status'] == 'cancelled' ? 'ملغى' : (a['paid'] == true ? 'مدفوع' : 'غير مدفوع'), style: TextStyle(fontSize: 12, color: a['paid'] == true ? C.green : C.grey)),
                  ]),
                ]),
              ),
          ]);
        }),
      );
}
