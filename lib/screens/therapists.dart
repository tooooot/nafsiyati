import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../theme.dart';
import 'profile.dart';

class TherapistsScreen extends StatelessWidget {
  const TherapistsScreen({super.key});
  @override
  Widget build(BuildContext context) => MintTop(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('المعالجون', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('الأقرب موعداً لك', style: TextStyle(color: C.grey)),
          const SizedBox(height: 16),
          for (final t in therapists) _Card(t),
        ]),
      );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 56});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: C.lotusSoft, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(name.replaceAll(RegExp(r'^(د\.|أ\.)\s*'), '').characters.first, style: TextStyle(fontSize: size * .4, fontWeight: FontWeight.w800, color: C.lotusDark)),
      );
}

class _Card extends StatelessWidget {
  final Therapist t;
  const _Card(this.t);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(t.name),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(t.title, style: const TextStyle(color: C.grey, fontSize: 13)),
              Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), Text(' ${t.rating}')]),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(t.bio, style: const TextStyle(color: C.grey, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [for (final x in t.topics) Chip(label: Text(x, style: const TextStyle(fontSize: 11)), backgroundColor: C.mintSoft, side: BorderSide.none, visualDensity: VisualDensity.compact)]),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(t))), child: const Text('عرض الملف')),
        ]),
      );
}
