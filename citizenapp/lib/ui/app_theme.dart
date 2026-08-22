import 'package:flutter/material.dart';

import 'package:citizenapp/ui/app_layout.dart';

/// citizenapp 统一浅色主题。
///
/// 设计语言：翠绿品牌色 + 干净白底 + 柔和阴影，体现公民治理 app 专业、可信赖的气质。
class AppTheme {
  AppTheme._();
  // 色板
  /// 背景色系
  static const Color scaffoldBg = Color(0xFFF7F9FC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF0F4F8);
  static const Color surfaceMuted = Color(0xFFF5F7FA);

  /// 主色（翠绿品牌色）
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primary = Color(0xFF007A74);
  static const Color primaryDark = Color(0xFF005A55);

  /// 辅助色
  static const Color accent = Color(0xFF26A69A);
  static const Color gold = Color(0xFFE5A100);

  /// 文字色
  static const Color textPrimary = Color(0xFF1A2B3C);
  static const Color textSecondary = Color(0xFF5A6B7C);
  static const Color textTertiary = Color(0xFF9AABB8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// 边框/分割线
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFEEF2F6);

  /// 语义色
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// 投票中 (蓝)
  static const Color voting = Color(0xFF3B82F6);

  /// 公民身份徽章色（链上身份档）：访客橙 / 投票蓝 / 竞选红。独立语义别名，
  /// 与 voting(投票中)/danger(危险)/warning(未生效) 解耦，避免撞色漂移。
  static const Color identityVisitor = gold; // 0xFFE5A100
  static const Color identityVoting = voting; // 0xFF3B82F6
  static const Color identityCandidate = danger; // 0xFFEF4444

  /// 已通过 (绿)
  static const Color passed = Color(0xFF22C55E);

  /// 已拒绝 (红)
  static const Color rejected = Color(0xFFEF4444);
  // 渐变
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF26A69A), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // 圆角 & 间距
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  // 卡片装饰
  static BoxDecoration cardDecoration({
    bool selected = false,
    double radius = radiusMd,
  }) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(radius)),
      border: Border.all(
        color: selected ? primary : border,
        width: selected ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B3D2E).withAlpha(selected ? 16 : 8),
          blurRadius: AppLayout.scaledValue(selected ? 12 : 6),
          offset: Offset(0, AppLayout.scaledValue(2)),
        ),
      ],
    );
  }

  // 状态提示装饰（用于 banner / 提示条）
  static BoxDecoration bannerDecoration(Color color) {
    return BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(
        AppLayout.scaledValue(radiusMd),
      ),
      border: Border.all(color: color.withAlpha(50)),
    );
  }

  // 提案状态颜色
  static Color proposalStatusColor(int status) {
    switch (status) {
      case 0:
        return voting;
      case 1:
        return passed;
      case 2:
        return rejected;
      case 3:
        return passed;
      case 4:
        return danger;
      default:
        return textTertiary;
    }
  }

  // ThemeData
  /// 1.0 基准主题，供 MaterialApp 启动和无 MediaQuery 的单元测试使用。
  static ThemeData get lightTheme => _buildLightTheme(1);

  /// 当前视口的动态主题。只缩放业务 UI，不替换系统文字倍率。
  static ThemeData lightThemeFor(BuildContext context) =>
      _buildLightTheme(AppLayout.visualScale(context));

  static ThemeData _buildLightTheme(double uiScale) {
    double scaled(double value) => value * uiScale;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Android/iOS 都使用同一套 Material 几何参数；平台仍可保留各自字体字形，
      // 但所有文字行框由下方 TextTheme 明确约束，不能再推动组件产生不同高度。
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surfaceCard,
        onSurface: textPrimary,
        error: danger,
        onError: Colors.white,
      ),
      iconTheme: IconThemeData(
        color: textSecondary,
        size: scaled(AppLayout.iconStandard),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: scaled(57),
          height: AppLayout.compactLineHeight,
        ),
        displayMedium: TextStyle(
          fontSize: scaled(45),
          height: AppLayout.compactLineHeight,
        ),
        displaySmall: TextStyle(
          fontSize: scaled(36),
          height: AppLayout.compactLineHeight,
        ),
        headlineLarge: TextStyle(
          fontSize: scaled(32),
          height: AppLayout.compactLineHeight,
        ),
        headlineMedium: TextStyle(
          fontSize: scaled(28),
          height: AppLayout.compactLineHeight,
        ),
        headlineSmall: TextStyle(
          fontSize: scaled(24),
          height: AppLayout.compactLineHeight,
        ),
        titleLarge: TextStyle(
          fontSize: scaled(22),
          height: AppLayout.compactLineHeight,
        ),
        titleMedium: TextStyle(
          fontSize: scaled(16),
          height: AppLayout.compactLineHeight,
        ),
        titleSmall: TextStyle(
          fontSize: scaled(14),
          height: AppLayout.compactLineHeight,
        ),
        bodyLarge: TextStyle(
          fontSize: scaled(16),
          height: AppLayout.bodyLineHeight,
        ),
        bodyMedium: TextStyle(
          fontSize: scaled(14),
          height: AppLayout.bodyLineHeight,
        ),
        bodySmall: TextStyle(
          fontSize: scaled(12),
          height: AppLayout.bodyLineHeight,
        ),
        labelLarge: TextStyle(
          fontSize: scaled(14),
          height: AppLayout.compactLineHeight,
        ),
        labelMedium: TextStyle(
          fontSize: scaled(12),
          height: AppLayout.compactLineHeight,
        ),
        labelSmall: TextStyle(
          fontSize: scaled(11),
          height: AppLayout.compactLineHeight,
        ),
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        toolbarHeight: scaled(AppLayout.appBarHeight),
        backgroundColor: surfaceCard,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: scaled(18),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: AppLayout.compactLineHeight,
        ),
        iconTheme: IconThemeData(
          color: textPrimary,
          size: scaled(AppLayout.iconStandard),
        ),
        actionsIconTheme: IconThemeData(
          color: textPrimary,
          size: scaled(AppLayout.iconStandard),
        ),
      ),
      // 全局返回键：统一为左向线性 chevron（与卡片右向 chevron_right 成对），
      // 一处覆盖所有 AppBar 自动生成的返回键；禁用带横杆的默认 arrow_back。
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.chevron_left),
      ),
      // Card
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      // Divider
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withAlpha(100),
          disabledForegroundColor: Colors.white70,
          minimumSize: Size(
            double.infinity,
            scaled(AppLayout.minimumButtonHeight),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scaled(radiusMd)),
          ),
          textStyle: TextStyle(
            fontSize: scaled(16),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: AppLayout.compactLineHeight,
          ),
        ),
      ),
      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: Size(
            double.infinity,
            scaled(AppLayout.minimumButtonHeight),
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scaled(radiusMd)),
          ),
          textStyle: TextStyle(
            fontSize: scaled(16),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: AppLayout.compactLineHeight,
          ),
        ),
      ),
      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: Size(
            double.infinity,
            scaled(AppLayout.minimumButtonHeight),
          ),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scaled(radiusMd)),
          ),
          textStyle: TextStyle(
            fontSize: scaled(16),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: AppLayout.compactLineHeight,
          ),
        ),
      ),
      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(
            AppLayout.minimumTapTarget,
            AppLayout.minimumTapTarget,
          ),
          textStyle: TextStyle(
            fontSize: scaled(14),
            height: AppLayout.compactLineHeight,
          ),
        ),
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        constraints: BoxConstraints(
          minHeight: scaled(AppLayout.inputBaseHeight),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: scaled(16),
          vertical: scaled(14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: scaled(AppLayout.bodyFontSize),
          height: AppLayout.compactLineHeight,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: scaled(AppLayout.bodyFontSize),
          height: AppLayout.compactLineHeight,
        ),
        counterStyle: TextStyle(
          color: textSecondary,
          fontSize: scaled(AppLayout.subtitleFontSize),
          height: AppLayout.compactLineHeight,
        ),
      ),
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaled(radiusLg)),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: scaled(18),
          fontWeight: FontWeight.w700,
          height: AppLayout.compactLineHeight,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: scaled(14),
          height: 1.5,
        ),
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: primary.withAlpha(25),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaled(radiusSm)),
        ),
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: scaled(AppLayout.supportingFontSize),
          height: AppLayout.compactLineHeight,
        ),
        secondaryLabelStyle: TextStyle(
          color: primary,
          fontSize: scaled(AppLayout.supportingFontSize),
          height: AppLayout.compactLineHeight,
        ),
      ),
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          height: AppLayout.bodyLineHeight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaled(radiusSm)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return surfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return border;
        }),
      ),
      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(
          horizontal: scaled(AppLayout.spaceLg),
        ),
        horizontalTitleGap: scaled(AppLayout.spaceMd),
        minLeadingWidth: scaled(AppLayout.iconStandard),
        minVerticalPadding: scaled(AppLayout.spaceSm),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: scaled(AppLayout.rowTitleFontSize),
          fontWeight: FontWeight.w600,
          height: AppLayout.compactLineHeight,
        ),
        subtitleTextStyle: TextStyle(
          color: textSecondary,
          fontSize: scaled(AppLayout.supportingFontSize),
          height: AppLayout.bodyLineHeight,
        ),
      ),
      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(scaled(radiusLg)),
          ),
        ),
      ),
      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(scaled(radiusMd)),
        ),
      ),
      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceCard,
        elevation: 0,
        height: scaled(AppLayout.navigationBarBaseHeight),
        indicatorColor: primary.withAlpha(20),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: primary,
              size: scaled(AppLayout.iconStandard),
            );
          }
          return IconThemeData(
            color: textTertiary,
            size: scaled(AppLayout.iconStandard),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: scaled(12),
              height: 1.2,
            );
          }
          return TextStyle(
            color: textTertiary,
            fontSize: scaled(12),
            height: 1.2,
          );
        }),
      ),
      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textTertiary,
        indicatorColor: primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: scaled(15),
          height: AppLayout.compactLineHeight,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: scaled(15),
          height: AppLayout.compactLineHeight,
        ),
      ),
      // Badge
      badgeTheme: BadgeThemeData(
        backgroundColor: danger,
        textColor: Colors.white,
        smallSize: scaled(8),
        largeSize: scaled(18),
      ),
    );
  }
}
