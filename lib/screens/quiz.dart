import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../theme.dart';
import 'home.dart';

/// استبيان التطابق — شريط تقدّم وخيارات كبيرة (Figma: Welcome to Nefsiyti 1/10..6/10).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0;
  final answers = <int, String>{};
  void _pick(String a) {
    answers[i] = a;
    if (i + 1 < questions.length) {
      setState(() => i++);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[i];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('أهلاً بك في نفسيتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: i > 0 ? IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => i--)) : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: (i + 1) / questions.length, minHeight: 6, color: C.green, backgroundColor: C.line),
          ),
          const SizedBox(height: 6),
          Text('${i + 1}/${questions.length}', style: const TextStyle(color: C.grey, fontSize: 12)),
          const SizedBox(height: 28),
          Text(q.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.5)),
          const SizedBox(height: 28),
          for (final o in q.options)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: ElevatedButton(onPressed: () => _pick(o), child: Text(o))),
        ]),
      ),
    );
  }
}
