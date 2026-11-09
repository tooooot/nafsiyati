import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../theme.dart';

typedef Connect = Future<({String url, String token})> Function();

class CallScreen extends StatefulWidget {
  final Connect connect;
  const CallScreen({super.key, required this.connect});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final room = Room();
  String? error;
  bool mic = true, cam = true, _otherSeen = false, _asking = false;

  @override
  void initState() {
    super.initState();
    room.addListener(() {
      if (room.remoteParticipants.isNotEmpty) _otherSeen = true;
      if (mounted) setState(() {});
    });
    _join();
  }

  Future<void> _join() async {
    try {
      final t = await widget.connect();
      await room.connect(t.url, t.token, roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  /// الخروج: «مغادرة مؤقتة» (تعود لاحقاً) أو «إنهاء الجلسة» (تُسجَّل منتهية) أو متابعة. زر الرجوع في أندرويد يمرّ بالسؤال نفسه.
  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('مغادرة الجلسة'),
        content: const Text('المغادرة المؤقتة تسمح لك بالعودة قبل انتهاء الوقت. إنهاء الجلسة يغلقها نهائياً ويفتح التقييم والملاحظات.'),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('متابعة الجلسة')),
          TextButton(onPressed: () => Navigator.pop(d, 'leave'), child: const Text('مغادرة مؤقتة')),
          TextButton(onPressed: () => Navigator.pop(d, 'end'), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('إنهاء الجلسة')),
        ],
      ),
    );
    _asking = false;
    if (r == null || !mounted) return;
    Navigator.pop(context, r == 'leave' ? 'leave' : (_otherSeen ? 'end_with' : 'end_alone'));
  }

  /// حالة الاتصال الصريحة (تتحدّث مع كل تغيّر في الغرفة).
  String _statusText() {
    if (error != null) return 'تعذّر الاتصال';
    return switch (room.connectionState.name) {
      'connected' => 'متصل',
      'reconnecting' => 'جارٍ إعادة الاتصال…',
      'disconnected' => 'انقطع الاتصال',
      _ => 'جارٍ الاتصال…',
    };
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
    final gone = _otherSeen && remote == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _ask(); },
      child: Scaffold(
      backgroundColor: const Color(0xFF101614),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: rv != null
                ? VideoTrackRenderer(rv)
                : Center(child: Text(error ?? (gone ? 'غادر الطرف الآخر الجلسة.\nيمكنك انتظار عودته أو إنهاء الجلسة.' : (remote == null ? 'بانتظار الطرف الآخر…' : 'الكاميرا مغلقة')), style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center)),
          ),
          if (lv != null)
            Positioned(
              top: 12, left: 12, width: 110, height: 150,
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: VideoTrackRenderer(lv, mirrorMode: VideoViewMirrorMode.mirror)),
            ),
          Positioned(top: 12, right: 12, child: Text(_statusText(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Positioned(
            bottom: 24, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(mic ? Icons.mic : Icons.mic_off, mic ? 'الميكروفون' : 'مكتوم', () async { mic = !mic; await room.localParticipant?.setMicrophoneEnabled(mic); setState(() {}); }, off: !mic),
              const SizedBox(width: 18),
              _btn(cam ? Icons.videocam : Icons.videocam_off, cam ? 'الكاميرا' : 'متوقفة', () async { cam = !cam; await room.localParticipant?.setCameraEnabled(cam); setState(() {}); }, off: !cam),
              const SizedBox(width: 18),
              _btn(Icons.call_end, gone ? 'إنهاء الجلسة' : 'إنهاء', _ask, red: true),
            ]),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _btn(IconData i, String label, VoidCallback f, {bool off = false, bool red = false}) => InkResponse(
        onTap: f,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: red ? Colors.red : (off ? Colors.white24 : Colors.white12)),
            child: Icon(i, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );
}
