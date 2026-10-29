import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/welcome.dart';

void main() => runApp(const NafsiyatiApp());

class NafsiyatiApp extends StatelessWidget {
  const NafsiyatiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'نفسيتي',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const WelcomeScreen(),
      );
}
