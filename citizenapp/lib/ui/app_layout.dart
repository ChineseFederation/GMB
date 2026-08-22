import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CitizenApp 跨平台视觉尺寸令牌。
///
/// 所有数值都是 411×914 设计视口下的基准值。业务 UI 通过 [visualScale]
/// 换算为当前设备的视觉尺寸；系统文字倍率仍只交给 Flutter 的
/// [MediaQuery.textScalerOf] 处理，SafeArea 也保持原生尺寸。
abstract final class AppLayout {
  static const double designWidth = 411;
  static const double designHeight = 914;
  static const double minimumVisualScale = 0.90;
  static const double maximumVisualScale = 1.10;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;

  static const double iconSmall = 18;
  static const double iconStandard = 24;
  static const double iconLarge = 32;

  static const double minimumTapTarget = 48;
  static const double minimumButtonHeight = 52;
  static const double appBarHeight = 56;
  static const double inputBaseHeight = 52;
  static const double serviceRowHeight = 64;
  static const double primaryEntryHeight = 70;
  static const double primaryEntryIconBox = 42;
  static const double navigationBarBaseHeight = 68;

  /// 公民二级 Tab 首行卡片的共享几何，禁止各页单独调整。
  static const double citizenSubtabFirstRowTopInset = 16;
  static const double citizenSubtabFirstRowHeight = 64;

  static const double rowTitleFontSize = 15;
  static const double bodyFontSize = 14;
  static const double supportingFontSize = 13;
  static const double subtitleFontSize = 12;

  static const double compactLineHeight = 1.2;
  static const double bodyLineHeight = 1.4;
  static const double subtitleLineHeight = 1.25;

  /// 根据完整逻辑视口计算唯一视觉倍率。
  ///
  /// 使用宽高比中较小值，保证不同纵横比的同尺寸手机都能放下同一套
  /// 业务 UI；不使用平台分支，也不把 SafeArea 再次扣除。
  @visibleForTesting
  static double visualScaleForSize(Size size) {
    final widthScale = size.width / designWidth;
    final heightScale = size.height / designHeight;
    return math
        .min(widthScale, heightScale)
        .clamp(minimumVisualScale, maximumVisualScale)
        .toDouble();
  }

  static double visualScale(BuildContext context) =>
      visualScaleForSize(MediaQuery.sizeOf(context));

  static double scaled(BuildContext context, double designValue) =>
      designValue * visualScale(context);

  /// 无 `BuildContext` 的纯视图辅助方法使用当前 FlutterView 换算设计值。
  ///
  /// CitizenApp 是单窗口移动应用；该入口专供不持有 context 的卡片子构建
  /// 方法使用。页面 build 和主题仍优先使用 [scaled]。
  static double scaledValue(double designValue) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null || view.devicePixelRatio <= 0) return designValue;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    return designValue * visualScaleForSize(logicalSize);
  }

  /// 触控区不跟随小屏缩到 48px 以下。
  static double tapTarget(BuildContext context, double designValue) =>
      math.max(minimumTapTarget, scaled(context, designValue));

  /// 当前系统对指定基础字号产生的真实行高。
  static double scaledLineHeight(
    BuildContext context, {
    required double fontSize,
    double height = 1.2,
  }) {
    final visualFontSize = scaled(context, fontSize);
    final scaledFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(visualFontSize);
    return scaledFontSize * height;
  }

  /// 主导航只补充文字相对 1.0 倍率增加的必要高度；图标、内边距和指示器不缩放。
  static double navigationBarHeight(BuildContext context) {
    const fontSize = 12.0;
    const lineHeight = 1.2;
    final scale = visualScale(context);
    final baselineTextHeight = fontSize * scale * lineHeight;
    final currentTextHeight = scaledLineHeight(
      context,
      fontSize: fontSize,
      height: lineHeight,
    );
    return navigationBarBaseHeight * scale +
        math.max(0, currentTextHeight - baselineTextHeight);
  }

  /// “我的”页钱包/身份两行入口的统一高度。
  ///
  /// 标准倍率由 42px 图标框决定为 70px；辅助字号只有在两行文字真实高度超过
  /// 图标框后才增加必要高度，避免平台字体默认行框改变基础卡片尺寸。
  static double primaryEntryCardHeight(BuildContext context) {
    final scale = visualScale(context);
    final verticalPadding = 14.0 * scale;
    final textGap = 3.0 * scale;
    final textHeight = scaledLineHeight(
          context,
          fontSize: rowTitleFontSize,
          height: compactLineHeight,
        ) +
        textGap +
        scaledLineHeight(
          context,
          fontSize: subtitleFontSize,
          height: subtitleLineHeight,
        );
    return verticalPadding * 2 +
        math.max(primaryEntryIconBox * scale, textHeight);
  }

  /// 单行个人服务入口标准为 64px；辅助字号超过 36px 图标槽后再增加高度。
  static double serviceEntryHeight(BuildContext context) {
    final scale = visualScale(context);
    final verticalPadding = 14.0 * scale;
    final iconSlot = 36.0 * scale;
    final textHeight = scaledLineHeight(
      context,
      fontSize: rowTitleFontSize,
      height: compactLineHeight,
    );
    return verticalPadding * 2 + math.max(iconSlot, textHeight);
  }
}
