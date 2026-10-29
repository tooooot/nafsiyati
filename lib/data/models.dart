class Slot {
  final String id;
  final DateTime start; // UTC
  final int minutes;
  Slot(this.id, this.start, this.minutes);
  factory Slot.fromJson(Map j) => Slot(j['id'], DateTime.parse(j['start']), j['minutes'] ?? 50);
}

class Therapist {
  final String id, name, title, bio, status;
  final List<String> topics, languages;
  final int priceDzd;
  final List<Slot> slots;
  Therapist(this.id, this.name, this.title, this.bio, this.status, this.topics, this.languages, this.priceDzd, this.slots);
  factory Therapist.fromJson(Map j) => Therapist(
        j['id'], j['name'] ?? '', j['title'] ?? '', j['bio'] ?? '', j['status'] ?? '',
        List<String>.from(j['topics'] ?? []), List<String>.from(j['languages'] ?? []), j['priceDzd'] ?? 0,
        [for (final s in (j['slots'] ?? [])) Slot.fromJson(s)],
      );
}

class Appointment {
  final String id, status;
  final String? therapist, patient;
  final DateTime start; // UTC
  final int minutes, priceDzd;
  Appointment(this.id, this.status, this.therapist, this.patient, this.start, this.minutes, this.priceDzd);
  factory Appointment.fromJson(Map j) => Appointment(j['id'], j['status'], j['therapist'], j['patient'], DateTime.parse(j['start']), j['minutes'] ?? 50, j['priceDzd'] ?? 0);
  DateTime get end => start.add(Duration(minutes: minutes));
  /// نافذة الدخول: قبل البدء بعشر دقائق حتى بعد النهاية بعشر دقائق (يطبّقها الخادم أيضاً).
  bool get joinable {
    final n = DateTime.now().toUtc();
    return status == 'booked' && n.isAfter(start.subtract(const Duration(minutes: 10))) && n.isBefore(end.add(const Duration(minutes: 10)));
  }
}

/// تنسيق الوقت المحلي: «اليوم 14:30» / «غداً 10:00» / «12/11 09:00».
String fmtTime(DateTime utc) {
  final l = utc.toLocal(), n = DateTime.now();
  final d0 = DateTime(n.year, n.month, n.day), d1 = DateTime(l.year, l.month, l.day);
  final diff = d1.difference(d0).inDays;
  String two(int x) => x.toString().padLeft(2, '0');
  final hm = '${two(l.hour)}:${two(l.minute)}';
  if (diff == 0) return 'اليوم $hm';
  if (diff == 1) return 'غداً $hm';
  return '${two(l.day)}/${two(l.month)} $hm';
}
