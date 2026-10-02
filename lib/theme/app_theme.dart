import 'package:flutter/material.dart';

/// Palet warna aplikasi yang mengikuti tema (gelap/terang).
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color inputHint;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color blue;
  final Color blueFg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color dangerBg;
  final Color planChipBg;
  final Color planChipFg;
  final Color stickerChipBg;
  final Color stickerChipFg;
  final Color avatarGrad1;
  final Color avatarGrad2;
  final Color avatarFg;
  final Color heroGrad1;
  final Color heroGrad2;
  final Color heroKode;
  final Color heroChipBg;
  final Color heroChipFg;
  final Color emptyIcon;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.inputHint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.blue,
    required this.blueFg,
    required this.dangerFg,
    required this.dangerBorder,
    required this.dangerBg,
    required this.planChipBg,
    required this.planChipFg,
    required this.stickerChipBg,
    required this.stickerChipFg,
    required this.avatarGrad1,
    required this.avatarGrad2,
    required this.avatarFg,
    required this.heroGrad1,
    required this.heroGrad2,
    required this.heroKode,
    required this.heroChipBg,
    required this.heroChipFg,
    required this.emptyIcon,
  });

  static const dark = AppColors(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceAlt: Color(0xFF273449),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFFFFFFF),
    textMuted: Color(0xFF94A3B8),
    inputHint: Color(0xFF64748B),
    accent: Color(0xFF22C55E),
    onAccent: Color(0xFF06250F),
    danger: Color(0xFFEF4444),
    blue: Color(0xFF3B82F6),
    blueFg: Color(0xFFEFF6FF),
    dangerFg: Color(0xFFF87171),
    dangerBorder: Color(0x66EF4444),
    dangerBg: Color(0x1FEF4444),
    planChipBg: Color(0xFF1E3A8A),
    planChipFg: Color(0xFF93C5FD),
    stickerChipBg: Color(0xFF166534),
    stickerChipFg: Color(0xFF86EFAC),
    avatarGrad1: Color(0xFF1E3A8A),
    avatarGrad2: Color(0xFF4338CA),
    avatarFg: Color(0xFFC7D2FE),
    heroGrad1: Color(0xFF1E3A8A),
    heroGrad2: Color(0xFF3730A3),
    heroKode: Color(0xFFBFDBFE),
    heroChipBg: Color(0x33FFFFFF),
    heroChipFg: Color(0xFFFFFFFF),
    emptyIcon: Color(0xFF475569),
  );

  static const light = AppColors(
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE2E8F0),
    border: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    inputHint: Color(0xFF94A3B8),
    accent: Color(0xFF16A34A),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    blue: Color(0xFF2563EB),
    blueFg: Color(0xFFFFFFFF),
    dangerFg: Color(0xFFDC2626),
    dangerBorder: Color(0xFFEF4444),
    dangerBg: Color(0xFFFEE2E2),
    planChipBg: Color(0xFFDBEAFE),
    planChipFg: Color(0xFF1E40AF),
    stickerChipBg: Color(0xFFDCFCE7),
    stickerChipFg: Color(0xFF15803D),
    avatarGrad1: Color(0xFF3B82F6),
    avatarGrad2: Color(0xFF6366F1),
    avatarFg: Color(0xFFFFFFFF),
    heroGrad1: Color(0xFF2563EB),
    heroGrad2: Color(0xFF4F46E5),
    heroKode: Color(0xFFDBEAFE),
    heroChipBg: Color(0x33FFFFFF),
    heroChipFg: Color(0xFFFFFFFF),
    emptyIcon: Color(0xFF94A3B8),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? inputHint,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? blue,
    Color? blueFg,
    Color? dangerFg,
    Color? dangerBorder,
    Color? dangerBg,
    Color? planChipBg,
    Color? planChipFg,
    Color? stickerChipBg,
    Color? stickerChipFg,
    Color? avatarGrad1,
    Color? avatarGrad2,
    Color? avatarFg,
    Color? heroGrad1,
    Color? heroGrad2,
    Color? heroKode,
    Color? heroChipBg,
    Color? heroChipFg,
    Color? emptyIcon,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      inputHint: inputHint ?? this.inputHint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      blue: blue ?? this.blue,
      blueFg: blueFg ?? this.blueFg,
      dangerFg: dangerFg ?? this.dangerFg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      dangerBg: dangerBg ?? this.dangerBg,
      planChipBg: planChipBg ?? this.planChipBg,
      planChipFg: planChipFg ?? this.planChipFg,
      stickerChipBg: stickerChipBg ?? this.stickerChipBg,
      stickerChipFg: stickerChipFg ?? this.stickerChipFg,
      avatarGrad1: avatarGrad1 ?? this.avatarGrad1,
      avatarGrad2: avatarGrad2 ?? this.avatarGrad2,
      avatarFg: avatarFg ?? this.avatarFg,
      heroGrad1: heroGrad1 ?? this.heroGrad1,
      heroGrad2: heroGrad2 ?? this.heroGrad2,
      heroKode: heroKode ?? this.heroKode,
      heroChipBg: heroChipBg ?? this.heroChipBg,
      heroChipFg: heroChipFg ?? this.heroChipFg,
      emptyIcon: emptyIcon ?? this.emptyIcon,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    AppColors o = other;
    return AppColors(
      background: Color.lerp(background, o.background, t)!,
      surface: Color.lerp(surface, o.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, o.surfaceAlt, t)!,
      border: Color.lerp(border, o.border, t)!,
      textPrimary: Color.lerp(textPrimary, o.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, o.textMuted, t)!,
      inputHint: Color.lerp(inputHint, o.inputHint, t)!,
      accent: Color.lerp(accent, o.accent, t)!,
      onAccent: Color.lerp(onAccent, o.onAccent, t)!,
      danger: Color.lerp(danger, o.danger, t)!,
      blue: Color.lerp(blue, o.blue, t)!,
      blueFg: Color.lerp(blueFg, o.blueFg, t)!,
      dangerFg: Color.lerp(dangerFg, o.dangerFg, t)!,
      dangerBorder: Color.lerp(dangerBorder, o.dangerBorder, t)!,
      dangerBg: Color.lerp(dangerBg, o.dangerBg, t)!,
      planChipBg: Color.lerp(planChipBg, o.planChipBg, t)!,
      planChipFg: Color.lerp(planChipFg, o.planChipFg, t)!,
      stickerChipBg: Color.lerp(stickerChipBg, o.stickerChipBg, t)!,
      stickerChipFg: Color.lerp(stickerChipFg, o.stickerChipFg, t)!,
      avatarGrad1: Color.lerp(avatarGrad1, o.avatarGrad1, t)!,
      avatarGrad2: Color.lerp(avatarGrad2, o.avatarGrad2, t)!,
      avatarFg: Color.lerp(avatarFg, o.avatarFg, t)!,
      heroGrad1: Color.lerp(heroGrad1, o.heroGrad1, t)!,
      heroGrad2: Color.lerp(heroGrad2, o.heroGrad2, t)!,
      heroKode: Color.lerp(heroKode, o.heroKode, t)!,
      heroChipBg: Color.lerp(heroChipBg, o.heroChipBg, t)!,
      heroChipFg: Color.lerp(heroChipFg, o.heroChipFg, t)!,
      emptyIcon: Color.lerp(emptyIcon, o.emptyIcon, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Palet warna potongan donut chart (berfungsi baik di tema gelap & terang).
const List<Color> kChartColors = [
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFF43F5E),
  Color(0xFF84CC16),
  Color(0xFF6366F1),
  Color(0xFF14B8A6),
  Color(0xFFA855F7),
  Color(0xFFF97316),
];

class AppTheme {
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  /// Radius sudut seragam di seluruh komponen.
  static const double radius = 14;

  /// Gaya border dasar (untuk input & dropdown).
  static OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  /// Skala tipografi yang dipakai tema (label, judul, isi).
  static TextTheme buildTextTheme(AppColors colors) => Typography
      .material2021(platform: TargetPlatform.android)
      .black
      .apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      )
      .copyWith(
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: colors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: colors.textMuted, fontSize: 14, height: 1.35),
        bodySmall: TextStyle(color: colors.textMuted, fontSize: 12),
        labelLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  /// Kursor "pointer/tangan" untuk semua elemen yang bisa diklik, supaya di
  /// web/desktop area interaktif tidak terlihat seperti teks biasa.
  static const WidgetStateProperty<MouseCursor?> kClickCursor =
      WidgetStatePropertyAll<MouseCursor?>(SystemMouseCursors.click);

  /// Provider warna tombol saat ditekan (partial-opacity hover/pressed).
  static WidgetStateProperty<Color?> accentOn(Color accent) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.pressed)
              ? accent.withValues(alpha: 0.6)
              : accent);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final radius = 14.0;
    final textTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          bodyColor: colors.textPrimary,
          displayColor: colors.textPrimary,
        )
        .copyWith(
          titleLarge: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: colors.textPrimary, fontSize: 15),
          bodyMedium: TextStyle(color: colors.textMuted, fontSize: 14, height: 1.4),
          labelLarge: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border),
    );

    WidgetStateProperty<Color?> accentOn(Color c) =>
        WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.pressed) ? c.withValues(alpha: 0.4) : c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.blue,
        onSecondary: colors.blueFg,
        error: colors.danger,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        outline: colors.border,
      ),
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceAlt,
        selectedColor: colors.planChipBg,
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(mouseCursor: kClickCursor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(mouseCursor: kClickCursor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, 46),
          textStyle: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(mouseCursor: kClickCursor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.blue,
        ).copyWith(mouseCursor: kClickCursor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(mouseCursor: kClickCursor),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.inputHint, fontSize: 14),
        labelStyle: TextStyle(color: colors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF334155)
            : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: colors.accent, width: 1.6),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: accentOn(colors.accent),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.accent.withValues(alpha: 0.85)
                : colors.surfaceAlt),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textMuted,
        textColor: colors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: IconThemeData(color: colors.textMuted),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.windows: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}