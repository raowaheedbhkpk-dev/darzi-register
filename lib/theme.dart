import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Darzi Register look: deep wine (the register's red border) with
/// tape-measure gold, on a soft rose-grey ground.
class AppColors {
  static const wine = Color(0xFF7A1631);
  static const wineDeep = Color(0xFF4A0C1E);
  static const gold = Color(0xFFD9A441);
  static const goldSoft = Color(0xFFF7E7C4);

  static const bgLight = Color(0xFFF5F1F2);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const lineLight = Color(0xFFE6DEE1);
  static const inkLight = Color(0xFF221A1D);
  static const mutedLight = Color(0xFF75676C);

  static const bgDark = Color(0xFF151012);
  static const surfaceDark = Color(0xFF201A1D);
  static const lineDark = Color(0xFF382D32);
  static const inkDark = Color(0xFFF2ECEE);
  static const mutedDark = Color(0xFFAE9FA5);
  static const wineOnDark = Color(0xFFEB7F98);
}

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color muted(BuildContext c) => isDark(c) ? AppColors.mutedDark : AppColors.mutedLight;
Color line(BuildContext c) => isDark(c) ? AppColors.lineDark : AppColors.lineLight;
Color wine(BuildContext c) => isDark(c) ? AppColors.wineOnDark : AppColors.wine;
Color surface(BuildContext c) => isDark(c) ? AppColors.surfaceDark : AppColors.surfaceLight;

/// Urdu (Nastaliq) text for measurement labels. Nastaliq needs extra line height.
TextStyle urdu({double size = 16, FontWeight weight = FontWeight.w600, Color? color, double height = 1.85}) =>
    GoogleFonts.notoNastaliqUrdu(fontSize: size, fontWeight: weight, color: color, height: height);

/// Figures: measurements, money, serial numbers.
TextStyle mono({double size = 16, FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? AppColors.bgDark : AppColors.bgLight;
  final surf = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  final ink = dark ? AppColors.inkDark : AppColors.inkLight;
  final mut = dark ? AppColors.mutedDark : AppColors.mutedLight;
  final ln = dark ? AppColors.lineDark : AppColors.lineLight;
  final primary = dark ? AppColors.wineOnDark : AppColors.wine;

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.wine, brightness: b).copyWith(
    primary: primary,
    onPrimary: dark ? AppColors.wineDeep : Colors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.wineDeep,
    surface: surf,
    onSurface: ink,
    onSurfaceVariant: mut,
    outline: mut,
    outlineVariant: ln,
    surfaceContainerHighest: dark ? const Color(0xFF2A2226) : const Color(0xFFF1EBED),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final text = GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
  final radius = BorderRadius.circular(14);

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: ink, letterSpacing: -.3),
    ),
    cardTheme: CardThemeData(
      color: surf,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: ln)),
    ),
    dividerTheme: DividerThemeData(color: ln, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF191416) : const Color(0xFFFBF9FA),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: mut),
      hintStyle: TextStyle(color: mut.withValues(alpha: .7)),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: ln)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: ln)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: primary, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: ink,
        side: BorderSide(color: ln, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary, textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surf,
      selectedColor: primary,
      side: BorderSide(color: ln),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
      secondaryLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onPrimary),
      checkmarkColor: scheme.onPrimary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surf,
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark ? AppColors.wine.withValues(alpha: .45) : AppColors.goldSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? primary : mut,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : mut, size: 24)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.inkDark : AppColors.wineDeep,
      contentTextStyle: GoogleFonts.manrope(color: dark ? AppColors.wineDeep : Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(backgroundColor: surf, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surf, surfaceTintColor: Colors.transparent),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
      subtitleTextStyle: GoogleFonts.manrope(fontSize: 13, color: mut, fontWeight: FontWeight.w500),
    ),
  );
}

/// Gold tape-measure strip with inch ticks — the app's signature detail.
class TapeStrip extends StatelessWidget {
  final double height;
  const TapeStrip({super.key, this.height = 18});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _TapePainter()));
}

class _TapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4));
    canvas.drawRRect(r, Paint()..color = AppColors.gold);
    final tick = Paint()
      ..color = AppColors.wineDeep.withValues(alpha: .75)
      ..strokeWidth = 1.2;
    const step = 9.0;
    var i = 0;
    for (double x = 6; x < size.width - 2; x += step, i++) {
      final h = i % 8 == 0 ? size.height * .62 : (i % 4 == 0 ? size.height * .45 : size.height * .28);
      canvas.drawLine(Offset(x, 0), Offset(x, h), tick);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
