import 'package:flutter/material.dart';
import '../data/api.dart';
import '../theme.dart';
import 'staff_screens.dart';

/// ملاحظات المعالج السرية عن الجلسة (لا يراها المريض؛ الخادم يمنعه).
class NotesScreen extends StatefulWidget {
  final String appointmentId;
  final String patient;
  const NotesScreen(this.appointmentId, this.patient, {super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final ctl = TextEditingController();
  bool loaded = false, busy = false;
  @override
  void initState() {
    super.initState();
    Api.get('/appointments/${widget.appointmentId}/notes').then((d) {
      ctl.text = '${(d as Map)['body'] ?? ''}';
      if (mounted) setState(() => loaded = true);
    }).catchError((_) {
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) => PageShell(
        'ملاحظات: ${widget.patient}',
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('هذه الملاحظات سرية ولا تظهر للمريض.', style: TextStyle(color: C.grey)),
            const SizedBox(height: 12),
            Expanded(child: TextField(controller: ctl, enabled: loaded, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: 'اكتب ملاحظاتك…'))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: busy || !loaded
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await act(context, () => Api.put('/appointments/${widget.appointmentId}/notes', {'body': ctl.text}));
                      if (mounted) {
                        setState(() => busy = false);
                        if (ok) toast(context, 'حُفظت الملاحظات');
                      }
                    },
              child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ]),
        ),
      );
}
