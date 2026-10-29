import 'dart:math';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../data/api.dart';
import '../theme.dart';

/// مدخل تجربة الفيديو: رمز غرفة يُشارَك بين الطرفين.
class DemoCallEntry extends StatefulWidget {
  const DemoCallEntry({super.key});
  @override
  State<DemoCallEntry> createState() => _DemoCallEntryState();
}

class _DemoCallEntryState extends State<DemoCallEntry> {
  final ctl = TextEditingController(text: _rand());
  static String _rand() {
    const a = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(6, (_) => a[r.nextInt(a.length)]).join();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تجربة جلسة الفيديو', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('افتح التطبيق على جهازين وأدخل نفس الرمز. الجلسة بين طرفين فقط.', style: TextStyle(color: C.grey)),
          const SizedBox(height: 20),
          TextField(
            controller: ctl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: 'رمز الغرفة', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final code = ctl.text.trim().toLowerCase();
              Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(room: 'demo-$code', name: 'مشارك')));
            },
            child: const Text('ادخل الجلسة'),
          ),
        ]),
      );
}

class CallScreen extends StatefulWidget {
  final String room, name;
  const CallScreen({super.key, required this.room, required this.name});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final room = Room();
  String status = 'جارٍ الاتصال…';
  String? error;
  bool mic = true, cam = true;

  @override
  void initState() {
    super.initState();
    room.addListener(() => mounted ? setState(() {}) : null);
    _join();
  }

  Future<void> _join() async {
    try {
      final t = await fetchVideoToken(widget.room, widget.name);
      await room.connect(t.url, t.token, roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(true);
      if (mounted) setState(() => status = 'متصل');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  VideoTrack? _video(Participant? p) {
    if (p == null) return null;
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is VideoTrack && !pub.muted) return t;
    }
    return null;
  }

  @override
  void dispose() {
    room.disconnect();
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = room.remoteParticipants.values.isEmpty ? null : room.remoteParticipants.values.first;
    final rv = _video(remote), lv = _video(room.localParticipant);
    return Scaffold(
      backgroundColor: const Color(0xFF101614),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: rv != null
                ? VideoTrackRenderer(rv)
                : Center(child: Text(error ?? (remote == null ? 'بانتظار الطرف الآخر…' : 'الكاميرا مغلقة'), style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center)),
          ),
          if (lv != null)
            Positioned(
              top: 12, left: 12, width: 110, height: 150,
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: VideoTrackRenderer(lv, mirrorMode: VideoViewMirrorMode.mirror)),
            ),
          Positioned(top: 12, right: 12, child: Text(status, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(mic ? Icons.mic : Icons.mic_off, () async { mic = !mic; await room.localParticipant?.setMicrophoneEnabled(mic); setState(() {}); }, off: !mic),
              const SizedBox(width: 18),
              _btn(cam ? Icons.videocam : Icons.videocam_off, () async { cam = !cam; await room.localParticipant?.setCameraEnabled(cam); setState(() {}); }, off: !cam),
              const SizedBox(width: 18),
              _btn(Icons.call_end, () => Navigator.pop(context), red: true),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _btn(IconData i, VoidCallback f, {bool off = false, bool red = false}) => InkResponse(
        onTap: f,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: red ? Colors.red : (off ? Colors.white24 : Colors.white12)),
          child: Icon(i, color: Colors.white),
        ),
      );
}
