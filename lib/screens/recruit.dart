import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/api.dart';
import '../theme.dart';
import 'staff_screens.dart';

const _stageIcons = {'found': Icons.search, 'sent': Icons.send_outlined, 'opened': Icons.visibility_outlined, 'registered': Icons.how_to_reg_outlined, 'learned': Icons.school_outlined, 'verified': Icons.verified_outlined, 'launched': Icons.rocket_launch_outlined};
const _order = ['found', 'sent', 'opened', 'registered', 'learned', 'verified', 'launched'];

/// تجنيد المعالجين: الهرم ثم المستهدفون ثم الإشعارات. الإرسال يدوي: يضغط المسوّق فتُفتح الرسالة جاهزة.
class RecruitScreen extends StatefulWidget {
  const RecruitScreen({super.key});
  @override
  State<RecruitScreen> createState() => _RecruitScreenState();
}

class _RecruitScreenState extends State<RecruitScreen> {
  int rev = 0;
  String stage = '', country = 'dz', city = 'الجزائر العاصمة';
  bool busy = false;
  Map? countries;

  @override
  void initState() {
    super.initState();
    Api.get('/recruit/countries').then((v) {
      if (mounted) setState(() => countries = v as Map);
    });
  }

  Future<void> _discover() async {
    setState(() => busy = true);
    try {
      final r = await Api.post('/recruit/discover', {'country': country, 'city': city}) as Map;
      if (mounted) toast(context, 'أُضيف ${r['added']} مكتب جديد من ${r['seen']} نتيجة');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() { busy = false; rev++; });
  }

  Future<void> _send(Map t) async {
    try {
      final r = await Api.post('/recruit/targets/${t['id']}/sent') as Map;
      final wa = '${r['wa']}';
      if (wa.isNotEmpty) {
        await launchUrl(Uri.parse(wa), mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: '${r['message']}'));
        if (mounted) toast(context, 'لا رقم لهذا المكتب؛ نُسخت الرسالة لإرسالها بالبريد');
      }
      if (mounted) setState(() => rev++);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  void _notes() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => SizedBox(
          height: 460,
          child: Loader('/recruit/notifications', (c2, d, _) {
            final items = ((d as Map)['items'] as List).cast<Map>();
            Api.post('/recruit/notifications/read');
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('آخر المستجدات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا مستجدات بعد.', style: TextStyle(color: C.grey)))),
              for (final n in items) ListTile(dense: true, leading: Icon(Icons.circle, size: 9, color: n['read'] == 1 ? C.line : C.green), title: Text('${n['text']}'), subtitle: Text(day('${n['created']}'), style: const TextStyle(fontSize: 11))),
            ]);
          }),
        ),
      ).then((_) => setState(() => rev++));

  void _detail(Map t) {
    final ev = (t['events'] as Map);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${t['name']}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in _order)
              ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(_stageIcons[s], color: ev[s] != null ? C.green : C.line), title: Text(_stageName[s]!), subtitle: ev[s] != null ? Text(day('${ev[s]}'), style: const TextStyle(fontSize: 11)) : null),
            const Divider(),
            Text('رابطه الشخصي', style: const TextStyle(color: C.grey, fontSize: 12)),
            SelectableText('${t['link']}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () async { await act(c, () => Api.post('/recruit/targets/${t['id']}/note', {'declined': !(t['declined'] as bool), 'note': t['note']})); if (c.mounted) Navigator.pop(c); setState(() => rev++); }, child: Text(t['declined'] == true ? 'إعادة الاعتبار' : 'اعتذر / لا يرغب')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = countries;
    final cities = cs == null ? <String>[] : ((cs[country] as Map)['cities'] as List).cast<String>();
    return PageShell(
      'تجنيد المعالجين',
      ListView(padding: const EdgeInsets.all(16), children: [
        Loader('/recruit/funnel?r=$rev', (c, d, _) {
          final f = d as Map;
          final st = (f['stages'] as List).cast<Map>();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [stat('المستهدفون', f['total']), stat('متأخرون +3 أيام', f['stuck'], color: Colors.orange.shade800), stat('اعتذروا', f['declined'])]),
            sectionTitle('الهرم'),
            for (final s in st)
              InkWell(
                onTap: () => setState(() => stage = stage == s['stage'] ? '' : '${s['stage']}'),
                child: box(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(_stageIcons[s['stage']], color: stage == s['stage'] ? C.green : C.grey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${s['name']}', style: TextStyle(fontWeight: stage == s['stage'] ? FontWeight.w800 : FontWeight.w500))),
                    Text('${s['count']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
              ),
          ]);
        }),
        sectionTitle('جلب مكاتب جديدة من خرائط Google'),
        if (cs != null)
          box(
            child: Column(children: [
              DropdownButtonFormField<String>(
                value: country,
                decoration: const InputDecoration(labelText: 'البلد'),
                items: [for (final k in cs.keys) DropdownMenuItem(value: '$k', child: Text('${(cs[k] as Map)['name']}'))],
                onChanged: (v) => setState(() { country = v!; city = ((cs[v] as Map)['cities'] as List).first; }),
              ),
              DropdownButtonFormField<String>(
                value: cities.contains(city) ? city : null,
                decoration: const InputDecoration(labelText: 'المدينة'),
                items: [for (final x in cities) DropdownMenuItem(value: x, child: Text(x))],
                onChanged: (v) => setState(() => city = v!),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(onPressed: busy ? null : _discover, icon: const Icon(Icons.travel_explore), label: Text(busy ? 'جارٍ الجلب…' : 'جلب المكاتب')),
            ]),
          ),
        sectionTitle(stage.isEmpty ? 'المستهدفون' : 'المستهدفون: ${_stageName[stage]}'),
        Loader('/recruit/targets?stage=$stage&r=$rev', (c, d, _) {
          final list = (d as List).cast<Map>();
          if (list.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا مستهدفين هنا بعد.', style: TextStyle(color: C.grey))));
          return Column(children: [
            for (final t in list)
              box(
                child: InkWell(
                  onTap: () => _detail(t),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      Chip(label: Text('${t['stageAr']}', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, backgroundColor: t['declined'] == true ? Colors.grey.shade300 : C.mintSoft),
                    ]),
                    Text('${t['city']}${(t['phone'] as String).isNotEmpty ? '  •  +${t['phone']}' : ''}', style: const TextStyle(color: C.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final s in _order) Expanded(child: Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: (t['events'] as Map)[s] != null ? C.green : C.line, borderRadius: BorderRadius.circular(3)))),
                    ]),
                    const SizedBox(height: 8),
                    if (t['declined'] != true && (t['events'] as Map)['sent'] == null) OutlinedButton.icon(onPressed: () => _send(t), icon: const Icon(Icons.send, size: 16), label: const Text('إرسال الدعوة')),
                    if (t['declined'] != true && (t['events'] as Map)['sent'] != null && (t['events'] as Map)['registered'] == null) TextButton.icon(onPressed: () => _send(t), icon: const Icon(Icons.replay, size: 16), label: const Text('تذكير')),
                  ]),
                ),
              ),
          ]);
        }),
      ]),
      actions: [
        Loader('/recruit/notifications?r=$rev', (c, d, _) {
          final n = (d as Map)['unread'] as int;
          return IconButton(tooltip: 'المستجدات', onPressed: _notes, icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications_outlined)));
        }),
      ],
    );
  }
}

const _stageName = {'found': 'تم العثور', 'sent': 'أُرسلت الدعوة', 'opened': 'فتح الصفحة', 'registered': 'سجّل', 'learned': 'أنهى التعليم', 'verified': 'تم التوثيق', 'launched': 'أُطلق للناس'};
