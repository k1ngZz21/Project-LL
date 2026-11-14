abstract final class ResponsiveLayout {
  static const double wideContentBreakpoint = 840;
  static const double contentMaxWidth = 1080;
  static const double mobileHorizontalPadding = 20;
  static const double wideHorizontalPadding = 36;

  static double horizontalPadding(double width) =>
      width >= wideContentBreakpoint
      ? wideHorizontalPadding
      : mobileHorizontalPadding;
}
