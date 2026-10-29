import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart' show fmtTime;
import '../theme.dart';
import 'admin.dart';
import 'therapists.dart' show ErrorBox;

/// لوحات الإدارة والتسويق والمالية. الخادم هو من يفرض الصلاحيات؛ هنا نعرض ما يسمح به فقط.
const permNames = {
  'stats': 'الأرقام العامة', 'users': 'المستخدمون', 'appointments': 'المواعيد', 'therapists': 'توثيق المعالجين', 'staff': 'أعضاء الإدارة',
  'vouchers': 'القسائم', 'growth': 'أرقام النمو', 'finance': 'الاطلاع على المالية', 'payments': 'تسجيل الدفعات',
};
const roleNames = {'admin': 'مدير', 'marketer': 'مسوّق', 'finance': 'مالية'};

String dzd(num n) => '$n دج';
String day(String iso) => fmtTime(DateTime.parse(iso));
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> act(BuildContext c, Future<dynamic> Function() f) async {
  try {
    await f();
    return true;
  } on ApiError catch (e) {
    if (c.mounted) toast(c, e.message);
    return false;
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const PageShell(this.title, this.child, {super.key, this.actions = const []});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
        body: child,
      );
}

/// يجلب مساراً ويعيد البناء عند الطلب.
class Loader extends StatefulWidget {
  final String path;
  final Widget Function(BuildContext, dynamic, VoidCallback reload) builder;
  const Loader(this.path, this.builder, {super.key});
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  late Future<dynamic> f = Api.get(widget.path);
  void reload() => setState(() => f = Api.get(widget.path));
  @override
  void didUpdateWidget(Loader old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) f = Api.get(widget.path);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: f,
        builder: (c, s) {
          if (s.hasError) return ErrorBox(s.error is ApiError ? (s.error as ApiError).message : 'تعذّر التحميل', onRetry: reload);
          if (!s.hasData) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: C.green)));
          return widget.builder(c, s.data, reload);
        },
      );
}

Widget box({required Widget child, EdgeInsets margin = const EdgeInsets.only(bottom: 10)}) => Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: child,
    );

Widget stat(String label, Object value, {Color? color}) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color ?? C.ink)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: C.grey), textAlign: TextAlign.center),
        ]),
      ),
    );

Widget sectionTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)));

Future<String?> askText(BuildContext c, String title, {String hint = '', TextInputType? kind}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, keyboardType: kind, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('حفظ')),
      ],
    ),
  );
}

// ───────────────────────── المركز: يعرض اللوحات المسموحة ─────────────────────────
class StaffHub extends StatelessWidget {
  final List perms;
  const StaffHub(this.perms, {super.key});
  bool has(String p) => perms.contains(p);
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData i, String t, Widget w) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: ListTile(leading: Icon(i, color: C.green), title: Text(t), trailing: const Icon(Icons.chevron_left), onTap: () => go(w)),
        );
    return PageShell('لوحات العمل', ListView(padding: const EdgeInsets.all(16), children: [
      if (has('stats') || has('users') || has('appointments') || has('therapists') || has('staff')) tile(Icons.dashboard_outlined, 'لوحة الإدارة', AdminDashboard(perms)),
      if (has('growth') || has('vouchers')) tile(Icons.campaign_outlined, 'لوحة التسويق', GrowthScreen(perms)),
      if (has('finance')) tile(Icons.account_balance_wallet_outlined, 'لوحة المالية', FinanceScreen(perms)),
    ]));
  }
}

// ───────────────────────── الإدارة ─────────────────────────
class AdminDashboard extends StatelessWidget {
  final List perms;
  const AdminDashboard(this.perms, {super.key});
  bool has(String p) => perms.contains(p);
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData i, String t, Widget w) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: ListTile(leading: Icon(i, color: C.green), title: Text(t), trailing: const Icon(Icons.chevron_left), onTap: () => go(w)),
        );
    return PageShell('لوحة الإدارة', ListView(padding: const EdgeInsets.all(12), children: [
      if (has('stats'))
        Loader('/admin/stats', (c, d, _) {
          final t = d['therapists'] as Map, a = d['appointments'] as Map;
          return Column(children: [
            Row(children: [stat('مستخدمون', d['users']), stat('معالجون موثّقون', t['verified']), stat('بانتظار التوثيق', t['pending'], color: (t['pending'] as int) > 0 ? Colors.orange : null)]),
            Row(children: [stat('حجوزات قادمة', a['upcoming']), stat('حجوزات نشطة', a['booked']), stat('ملغاة', a['cancelled'])]),
          ]);
        }),
      const SizedBox(height: 10),
      if (has('therapists')) tile(Icons.verified_user_outlined, 'توثيق المعالجين', const AdminScreen()),
      if (has('users')) tile(Icons.people_outline, 'المستخدمون', const UsersScreen()),
      if (has('appointments')) tile(Icons.event_note_outlined, 'كل المواعيد', const AppointmentsAdminScreen()),
      if (has('staff')) tile(Icons.admin_panel_settings_outlined, 'أعضاء الإدارة والصلاحيات', const StaffScreen()),
    ]));
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) => PageShell(
        'المستخدمون',
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(decoration: const InputDecoration(hintText: 'ابحث بالاسم أو البريد', prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white), onSubmitted: (v) => setState(() => q = v.trim())),
          ),
          Expanded(
            child: Loader('/admin/users?q=${Uri.encodeQueryComponent(q)}', (c, d, reload) {
              final list = (d as List).cast<Map>();
              if (list.isEmpty) return const Center(child: Text('لا نتائج.', style: TextStyle(color: C.grey)));
              return ListView(children: [
                for (final u in list)
                  ListTile(
                    title: Text('${u['name'] ?? ''}'.isEmpty ? '${u['email']}' : '${u['name']}'),
                    subtitle: Text('${u['email']}'),
                    trailing: Switch(
                      value: u['suspended'] == true,
                      activeColor: Colors.red,
                      onChanged: (v) async {
                        if (await act(c, () => Api.post('/admin/users/${u['id']}/suspend', {'suspended': v}))) reload();
                      },
                    ),
                  ),
              ]);
            }),
          ),
        ]),
      );
}

class AppointmentsAdminScreen extends StatelessWidget {
  const AppointmentsAdminScreen({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
        'كل المواعيد',
        Loader('/admin/appointments', (c, d, _) {
          final list = (d as List).cast<Map>();
          if (list.isEmpty) return const Center(child: Text('لا مواعيد.', style: TextStyle(color: C.grey)));
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final a in list)
              box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a['therapist'] ?? ''} ← ${a['patient'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(day(a['start']), style: const TextStyle(color: C.grey)),
                  Text('${a['status'] == 'booked' ? 'محجوز' : 'ملغى'} • ${dzd(a['priceDzd'])} • ${a['paid'] == true ? 'مدفوع' : 'غير مدفوع'}'),
                ]),
              ),
          ]);
        }),
      );
}

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int rev = 0;
  Future<void> _add(BuildContext c, Map d) async {
    final email = await askText(c, 'بريد العضو (Google أو Apple)', hint: 'name@gmail.com', kind: TextInputType.emailAddress);
    if (email == null || email.isEmpty || !c.mounted) return;
    final role = await showDialog<String>(
      context: c,
      builder: (_) => SimpleDialog(title: const Text('الدور'), children: [for (final e in roleNames.entries) SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key), child: Text(e.value))]),
    );
    if (role == null || !c.mounted) return;
    if (await act(c, () => Api.post('/admin/staff', {'email': email, 'role': role}))) setState(() => rev++);
  }

  Future<void> _perms(BuildContext c, Map m, List all) async {
    final sel = {...(m['perms'] as List).cast<String>()};
    final ok = await showDialog<bool>(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, set) => AlertDialog(
          title: Text('صلاحيات ${m['email']}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final p in all.cast<String>())
                CheckboxListTile(dense: true, value: sel.contains(p), title: Text(permNames[p] ?? p), onChanged: (v) => set(() => v == true ? sel.add(p) : sel.remove(p))),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(c2, true), child: const Text('حفظ'))],
        ),
      ),
    );
    if (ok == true && c.mounted && await act(c, () => Api.put('/admin/staff/${Uri.encodeComponent(m['email'])}', {'perms': sel.toList()}))) setState(() => rev++);
  }

  @override
  Widget build(BuildContext context) => PageShell(
        'أعضاء الإدارة والصلاحيات',
        Loader('/admin/staff?r=$rev', (c, d, _) {
          final staff = (d['staff'] as List).cast<Map>(), all = d['all'] as List;
          return ListView(padding: const EdgeInsets.all(12), children: [
            ElevatedButton.icon(onPressed: () => _add(c, d), icon: const Icon(Icons.person_add_alt), label: const Text('إضافة عضو')),
            const SizedBox(height: 12),
            if (staff.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا أعضاء بعد. أضف بريداً ليُمنح دوراً عند أول دخول له.', style: TextStyle(color: C.grey), textAlign: TextAlign.center))),
            for (final m in staff)
              box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['email']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(roleNames[m['role']] ?? '${m['role']}', style: const TextStyle(color: C.grey)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [for (final p in (m['perms'] as List)) Chip(label: Text(permNames[p] ?? '$p', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)]),
                  Row(children: [
                    TextButton(onPressed: () => _perms(c, m, all), child: const Text('تعديل الصلاحيات')),
                    TextButton(
                      onPressed: () async {
                        if (await act(c, () => Api.delete('/admin/staff/${Uri.encodeComponent(m['email'])}'))) setState(() => rev++);
                      },
                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ]),
                ]),
              ),
          ]);
        }),
      );
}

// ───────────────────────── التسويق ─────────────────────────
class GrowthScreen extends StatefulWidget {
  final List perms;
  const GrowthScreen(this.perms, {super.key});
  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  int rev = 0;
  Future<void> _newVoucher(BuildContext c) async {
    final code = await askText(c, 'كود القسيمة', hint: 'WELCOME20');
    if (code == null || code.isEmpty || !c.mounted) return;
    final pct = await askText(c, 'نسبة الخصم %', hint: '20', kind: TextInputType.number);
    if (pct == null || !c.mounted) return;
    final uses = await askText(c, 'أقصى عدد استعمالات (0 = بلا حد)', hint: '0', kind: TextInputType.number);
    if (uses == null || !c.mounted) return;
    if (await act(c, () => Api.post('/vouchers', {'code': code, 'percent': int.tryParse(pct) ?? 0, 'maxUses': int.tryParse(uses) ?? 0}))) setState(() => rev++);
  }

  @override
  Widget build(BuildContext context) => PageShell(
        'لوحة التسويق',
        ListView(padding: const EdgeInsets.all(12), children: [
          if (widget.perms.contains('growth'))
            Loader('/growth?r=$rev', (c, d, _) {
              final f = d['funnel'] as Map, daily = (d['daily'] as List).cast<Map>();
              final mx = daily.fold<int>(1, (m, e) => (e['count'] as int) > m ? e['count'] as int : m);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                sectionTitle('مسار المستخدم'),
                Row(children: [stat('سجّلوا', f['users']), stat('أكملوا الاستبيان', f['quiz']), stat('حجزوا', f['booked']), stat('دفعوا', f['paid'])]),
                sectionTitle('التسجيلات الجديدة (14 يوماً)'),
                box(
                  child: SizedBox(
                    height: 110,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final e in daily)
                        Expanded(child: Tooltip(message: '${e['date']}: ${e['count']}', child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 6 + 100 * (e['count'] as int) / mx, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(3))))),
                    ]),
                  ),
                ),
                Row(children: [stat('معالجون موثّقون', (d['therapists'] as Map)['verified']), stat('بانتظار التوثيق', (d['therapists'] as Map)['pending'])]),
              ]);
            }),
          if (widget.perms.contains('vouchers')) ...[
            sectionTitle('القسائم'),
            ElevatedButton.icon(onPressed: () => _newVoucher(context), icon: const Icon(Icons.add), label: const Text('قسيمة جديدة')),
            const SizedBox(height: 10),
            Loader('/vouchers?r=$rev', (c, d, _) {
              final list = (d as List).cast<Map>();
              if (list.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا قسائم بعد.', style: TextStyle(color: C.grey))));
              return Column(children: [
                for (final v in list)
                  box(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${v['code']}  •  ${v['percent']}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('استُعملت ${v['used']}${(v['maxUses'] as int) > 0 ? ' من ${v['maxUses']}' : ''}', style: const TextStyle(color: C.grey, fontSize: 12)),
                        ]),
                      ),
                      Switch(
                        value: v['active'] == true,
                        onChanged: (x) async {
                          if (await act(c, () => Api.post('/vouchers/${v['code']}/toggle', {'active': x}))) setState(() => rev++);
                        },
                      ),
                    ]),
                  ),
              ]);
            }),
          ],
        ]),
      );
}

// ───────────────────────── المالية ─────────────────────────
class FinanceScreen extends StatefulWidget {
  final List perms;
  const FinanceScreen(this.perms, {super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  int rev = 0;
  bool get canPay => widget.perms.contains('payments');

  Future<void> _paid(BuildContext c, Map a) async {
    final m = await showDialog<String>(
      context: c,
      builder: (_) => SimpleDialog(title: Text('تأكيد استلام ${dzd(a['priceDzd'])}'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'cash'), child: const Text('نقداً')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'baridimob'), child: const Text('بريدي موب')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'bank'), child: const Text('تحويل بنكي')),
      ]),
    );
    if (m != null && c.mounted && await act(c, () => Api.post('/finance/appointments/${a['id']}/paid', {'method': m}))) setState(() => rev++);
  }

  Future<void> _payout(BuildContext c, Map t) async {
    final v = await askText(c, 'مبلغ التحويل إلى ${t['name']}', hint: '${t['balance']}', kind: TextInputType.number);
    final n = int.tryParse(v ?? '');
    if (n != null && c.mounted && await act(c, () => Api.post('/finance/payouts', {'therapistId': t['therapistId'], 'amount': n}))) setState(() => rev++);
  }

  @override
  Widget build(BuildContext context) => PageShell(
        'لوحة المالية',
        ListView(padding: const EdgeInsets.all(12), children: [
          Loader('/finance/summary?r=$rev', (c, d, _) {
            final ts = (d['therapists'] as List).cast<Map>();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [stat('المحصَّل', dzd(d['gross'])), stat('عمولة المنصة ${d['feePercent']}%', dzd(d['platformFee']), color: C.green)]),
              Row(children: [stat('مستحق للمعالجين', dzd(d['therapistsPayable'])), stat('غير محصَّل (${d['unpaidCount']})', dzd(d['outstanding']), color: Colors.orange)]),
              sectionTitle('أرصدة المعالجين'),
              if (ts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('لا مدفوعات مسجّلة بعد.', style: TextStyle(color: C.grey)))),
              for (final t in ts)
                box(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('الإجمالي ${dzd(t['gross'])} • العمولة ${dzd(t['fee'])} • حُوّل ${dzd(t['paidOut'])}', style: const TextStyle(color: C.grey, fontSize: 12)),
                        Text('الرصيد المستحق: ${dzd(t['balance'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (canPay) OutlinedButton(onPressed: () => _payout(c, t), child: const Text('تحويل')),
                  ]),
                ),
            ]);
          }),
          sectionTitle('جلسات بانتظار التحصيل'),
          Loader('/finance/appointments?paid=0&r=$rev', (c, d, _) {
            final list = (d as List).cast<Map>();
            if (list.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('لا شيء بانتظار التحصيل.', style: TextStyle(color: C.grey))));
            return Column(children: [
              for (final a in list)
                box(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${a['therapist'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${day(a['start'])} • ${dzd(a['priceDzd'])}${a['voucher'] != null ? ' • قسيمة ${a['voucher']}' : ''}', style: const TextStyle(color: C.grey, fontSize: 12)),
                      ]),
                    ),
                    if (canPay) ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)), onPressed: () => _paid(c, a), child: const Text('تأكيد الدفع')),
                  ]),
                ),
            ]);
          }),
        ]),
      );
}
