import 'package:flutter/material.dart';

// IPTV Deck inspired cinema-dark obsidian, electric cyan, and champagne gold palette
const kBg = Color(0xFF05060B);
const kPanel = Color(0xFF0C0E16);
const kSurface = Color(0xFF10131E);
const kSurface2 = Color(0xFF171B2A);
const kBorder = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
const kBorderSoft = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)

const kCyan = Color(0xFF22D3EE);
const kGold = Color(0xFFD9BC84);
const kGoldInk = Color(0xFF17130A);
const kLive = Color(0xFFEF4444);
const kOk = Color(0xFF34D399);
const kText = Color(0xFFEDEFF7);
const kTextSoft = Color(0xFFC6CCDA);
const kTextMuted = Color(0xFF8B93A7);

// Alias kept for compatibility
const kAccent = kCyan;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kCyan,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kCyan,
    onPrimary: const Color(0xFF03171B),
    secondary: kGold,
    onSecondary: kGoldInk,
    surface: kPanel,
    onSurface: kText,
    error: kLive,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    canvasColor: kPanel,
    dividerColor: kBorderSoft,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: kText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: kPanel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: kBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kPanel,
      indicatorColor: kCyan.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? kCyan : kTextMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? kCyan : kTextMuted,
          size: 22,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface2,
      selectedColor: kCyan.withValues(alpha: 0.20),
      checkmarkColor: kCyan,
      labelStyle: const TextStyle(color: kTextSoft, fontSize: 12.5, fontWeight: FontWeight.w500),
      side: const BorderSide(color: kBorderSoft),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface2,
      hintStyle: const TextStyle(color: kTextMuted),
      labelStyle: const TextStyle(color: kTextSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCyan, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kCyan,
        foregroundColor: const Color(0xFF041418),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kText,
        side: const BorderSide(color: kBorder),
        shape: const StadiumBorder(),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.w800, letterSpacing: -0.6),
      titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: TextStyle(color: kText, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleSmall: TextStyle(color: kTextSoft, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: kText),
      bodySmall: TextStyle(color: kTextMuted),
    ),
  );
}

class LiveBadge extends StatelessWidget {
  final String text;
  const LiveBadge({this.text = 'CANLI', super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: kLive,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
        ]),
      );
}

class TagPill extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  const TagPill(this.label, {this.color, this.textColor, super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color ?? kSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? kTextSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      );
}

class RatingBadge extends StatelessWidget {
  final String rating;
  const RatingBadge(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = rating.trim();
    if (v.isEmpty || v == '0' || v == '0.0' || v == 'null') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kGold.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 12, color: kGold),
        const SizedBox(width: 2),
        Text(v, style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
