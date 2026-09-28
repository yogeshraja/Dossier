/// Responsive Breakpoints & Viewport Constraints
/// Monorepo: Dossier Kiosk Client
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMin = 320.0;
  static const double mobileMax = 640.0;
  static const double tabletMax = 1000.0;
  static const double desktopMax = 1440.0;

  static bool isMobile(double width) => width < mobileMax;
  static bool isTablet(double width) => width >= mobileMax && width < tabletMax;
  static bool isDesktop(double width) => width >= tabletMax;
  static bool isUltraWide(double width) => width >= desktopMax;
}
