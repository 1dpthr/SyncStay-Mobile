import 'package:flutter/material.dart';

/// Media-query helpers for responsive layouts across screen sizes.
class Responsive {
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isMobile(BuildContext context) => screenWidth(context) < 600;

  static bool isTablet(BuildContext context) {
    final w = screenWidth(context);
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1024;

  static bool isCompact(BuildContext context) => screenWidth(context) < 420;

  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 48;
    if (isTablet(context)) return 32;
    return 20;
  }

  static double quickActionCardWidth(BuildContext context) {
    final w = screenWidth(context);
    if (w < 360) return w - horizontalPadding(context) * 2;
    if (isCompact(context)) return (w - horizontalPadding(context) * 2 - 16) / 2;
    return 160;
  }

  static double statCardWidth(BuildContext context) {
    final w = screenWidth(context);
    if (isCompact(context)) return w - horizontalPadding(context) * 2;
    return 170;
  }

  static int gridCrossAxisCount(BuildContext context, {int max = 2}) {
    if (isDesktop(context)) return max.clamp(2, 4);
    if (isTablet(context)) return 2;
    return isCompact(context) ? 1 : 2;
  }
}
