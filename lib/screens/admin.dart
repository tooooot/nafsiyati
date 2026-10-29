import 'package:flutter/material.dart';
import '../data/api.dart';
import '../theme.dart';
import 'therapists.dart';

/// إدارة المعالجين: مراجعة طلبات التسجيل وتوثيقها أو رفضها (للمدير فقط؛ الخادم يتحقق).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String status = 'pending';
  late Future<dynamic> f = _load();
  static const names = {'pending': 'قيد المراجعة', 'verified': 'موثّقون', 'rejected': 'مرفوضون'};

  Future<dynamic> _load() => Api.get('/admin/therapists?status=$status');
  void _reload() => setState(() => f = _load());

  Future<void> _set(String id, String st) async {
    try {
      await Api.post('/admin/therapists/$id/status', {'status': st});
      _reload();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إدارة المعالجين'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, children: [
              for (final e in names.entries)
                ChoiceChip(label: Text(e.value), selected: status == e.key, onSelected: (_) { status = e.key; _reload(); }),
            ]),
          ),
          Expanded(
            child: FutureBuilder(
              future: f,
              builder: (c, s) {
                if (s.hasError) return ErrorBox(s.error is ApiError ? (s.error as ApiError).message : 'تعذّر التحميل', onRetry: _reload);
                if (!s.hasData) return const Center(child: CircularProgressIndicator(color: C.green));
                final list = (s.data as List).cast<Map>();
                if (list.isEmpty) return const Center(child: Text('لا طلبات هنا.', style: TextStyle(color: C.grey)));
                return ListView(padding: const EdgeInsets.all(12), children: [for (final t in list) _card(t)]);
              },
            ),
          ),
        ]),
      );

  Widget _card(Map t) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if ('${t['title'] ?? ''}'.isNotEmpty) Text('${t['title']}', style: const TextStyle(color: C.grey)),
          const SizedBox(height: 6),
          Text('رقم الترخيص: ${t['licenseNo']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('السعر: ${t['priceDzd']} دج'),
          if ((t['topics'] as List).isNotEmpty) Text('التخصصات: ${(t['topics'] as List).join('، ')}'),
          if ('${t['bio'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${t['bio']}', style: const TextStyle(color: C.grey))),
          const SizedBox(height: 10),
          Row(children: [
            if (status != 'verified') Expanded(child: ElevatedButton(onPressed: () => _set('${t['id']}', 'verified'), child: const Text('توثيق'))),
            if (status == 'pending') const SizedBox(width: 8),
            if (status != 'rejected') Expanded(child: OutlinedButton(onPressed: () => _set('${t['id']}', 'rejected'), child: Text(status == 'verified' ? 'إيقاف' : 'رفض'))),
          ]),
        ]),
      );
}
