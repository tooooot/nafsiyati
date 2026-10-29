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
  bool mic = true, cam = true;

  @override
  void initState() {
    super.initState();
    room.addListener(() => mounted ? setState(() {}) : null);
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
          Positioned(top: 12, right: 12, child: Text(_statusText(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
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
