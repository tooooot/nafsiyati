import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان مأخوذة من تصميم Figma المعتمد (2026-10-28).
class C {
  static const green = Color(0xFF15B788);
  static const mint = Color(0xFF3CE3B3);
  static const mintSoft = Color(0xFFC2EFC9);
  static const ink = Color(0xFF1A1A1A);
  static const grey = Color(0xFF7A7A7A);
  static const line = Color(0xFFDDDDDD);
  static const bg = Color(0xFFF8F8F8);
  static const lotusDark = Color(0xFF43308F);
  static const lotusMid = Color(0xFF7A6BC0);
  static const lotusSoft = Color(0xFFC4B9F5);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green, primary: C.green),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// تدرّج أخضر مائي أعلى الشاشات كما في التصميم.
class MintTop extends StatelessWidget {
  final Widget child;
  const MintTop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0xFFB9F0DC), C.bg],
          ),
        ),
        child: child,
      );
}
