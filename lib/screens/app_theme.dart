import 'package:flutter/material.dart';

/// نظام التصميم - أسلوب Material 3 Expressive
/// ألوان جريئة، انحناءات أوسع (Squircle)، ظلال ملوّنة بدل السوداء التقليدية
class AppTheme {
  AppTheme._();

  // ==================== الألوان الأساسية (عائلة تونية موسّعة) ====================
  static const Color primary = Color(0xFF0B6E9C);
  static const Color primaryDark = Color(0xFF054A6B);
  static const Color primaryLight = Color(0xFFDCEEF7);

  static const Color secondary = Color(0xFFE8720C); // برتقالي دافئ - لون ثانوي معبّر
  static const Color secondaryLight = Color(0xFFFDEAD9);

  static const Color tertiary = Color(0xFF7C3AED); // بنفسجي - لون ثالث معبّر
  static const Color tertiaryLight = Color(0xFFF0E9FD);

  static const Color success = Color(0xFF1A9948);
  static const Color successLight = Color(0xFFE3F5E9);
  static const Color warning = Color(0xFFF59F0A);
  static const Color warningLight = Color(0xFFFEF3E2);
  static const Color destructive = Color(0xFFE23E3E);
  static const Color destructiveLight = Color(0xFFFCE9E9);

  // أسماء متوافقة مع الكود القديم (بعض الشاشات تستخدم purple/purpleLight)
  static const Color purple = tertiary;
  static const Color purpleLight = tertiaryLight;

  static const Color background = Color(0xFFF7F8FB);
  static const Color cardBackground = Colors.white;
  static const Color border = Color(0xFFEAEDF2);
  static const Color textPrimary = Color(0xFF171E2E);
  static const Color textMuted = Color(0xFF6B7280);

  /// تدرّج أساسي جريء - ترويسات وكروت مميّزة
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [primary, primaryDark],
  );

  /// تدرّج ثانوي دافئ - لتنويع بصري بالكروت المميّزة
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, Color(0xFFC85A00)],
  );

  /// نصف قطر الانحناء المعبّر (Squircle) - أوسع من الستايل التقليدي
  static const double radiusLg = 28;
  static const double radiusMd = 20;
  static const double radiusSm = 14;

  /// ظل ملوّن ناعم (بدل الأسود التقليدي) - يعطي إحساس "طافي" حديث
  static List<BoxShadow> tintedShadow([Color color = primary]) => [
        BoxShadow(
          color: color.withValues(alpha: 0.14),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get softShadow => tintedShadow(primary);

  static ThemeData themeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: cardBackground,
      ),
      fontFamily: 'Tajawal',
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape: const StadiumBorder(), // شكل حبّة الدواء (Pill) - سمة Expressive
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: background,
        selectedColor: primaryLight,
        labelStyle: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(side: BorderSide(color: border)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}

/// كرت مؤشر أداء (KPI) - ستايل Expressive: أيقونة بلون جريء داخل مربع دائري الحواف، ظل ملوّن
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? trend;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.tintedShadow(color),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.1),
                    overflow: TextOverflow.ellipsis),
                if (trend != null) ...[
                  const SizedBox(height: 2),
                  Text(trend!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18), // squircle معبّر
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }
}

/// عنوان قسم موحّد - نسخة Expressive بانحناء أوسع وظل ملوّن
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final Color accent;

  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.trailing,
    this.accent = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.tintedShadow(accent),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: accent),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ],
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة - أيقونة داخل دائرة ملوّنة كبيرة
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: accent.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// شارة حالة - شكل حبّة دواء (Stadium) بدل المستطيل الدائري التقليدي
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// حاوية أيقونة معبّرة (Squircle) - تُستخدم بدل Icon() المباشرة داخل الكروت
class ExpressiveIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final double size;

  const ExpressiveIconBox({
    super.key,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}
