import 'package:flutter/material.dart';

/// Centralized UI Dimensions & Spatial Tokens
/// Monorepo: Dossier Kiosk Client
class AppDimensions {
  AppDimensions._();

  // Spacing & Padding
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // Edge Insets Shorthands
  static const EdgeInsets paddingXS = EdgeInsets.all(space4);
  static const EdgeInsets paddingSM = EdgeInsets.all(space8);
  static const EdgeInsets paddingMD = EdgeInsets.all(space16);
  static const EdgeInsets paddingLG = EdgeInsets.all(space24);
  static const EdgeInsets paddingXL = EdgeInsets.all(space32);

  // Border Radii
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusFull = 9999.0;

  static const BorderRadius borderRadiusXS = BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderRadiusSM = BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius borderRadiusMD = BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius borderRadiusLG = BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius borderRadiusXL = BorderRadius.all(Radius.circular(radiusXL));

  // Component Dimensions
  static const double buttonHeightSM = 36.0;
  static const double buttonHeightMD = 44.0;
  static const double buttonHeightLG = 52.0;
  static const double inputHeight = 48.0;
  static const double searchBarHeight = 44.0;
  static const double appHeaderHeight = 64.0;
  static const double bottomNavHeight = 64.0;

  // Sidebar Dimensions
  static const double sidebarExpandedWidth = 240.0;
  static const double sidebarCollapsedWidth = 76.0;

  // Resizable Split View Panel Bounds
  static const double panelMinWidth = 220.0;
  static const double panelMaxWidth = 640.0;
  static const double panelDefaultSplitRatio = 0.5;
  static const double splitDividerWidth = 6.0;
  static const double splitDividerTouchArea = 16.0;

  // Icon Sizes
  static const double iconXS = 14.0;
  static const double iconSM = 18.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;

  // Glassmorphism Blur Radii
  static const double glassBlurSigma = 12.0;
  static const double glassBorderWidth = 1.0;

  // Thermal Receipt Printing Formats
  static const int receiptCharsPerLine58mm = 32;
  static const int receiptCharsPerLine80mm = 48;
}
