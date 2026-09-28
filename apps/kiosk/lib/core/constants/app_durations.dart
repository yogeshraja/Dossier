/// Centralized Animation & Timing Durations
/// Monorepo: Dossier Kiosk Client
class AppDurations {
  AppDurations._();

  // Micro-Animations & Transitions
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration deliberate = Duration(milliseconds: 600);

  // Debounce & Throttling
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration autoSaveDebounce = Duration(milliseconds: 800);

  // User Notification Timers
  static const Duration toastDuration = Duration(seconds: 3);
  static const Duration bannerDuration = Duration(seconds: 5);
  static const Duration otpCountdown = Duration(seconds: 30);

  // Network Timeouts
  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration syncPollInterval = Duration(seconds: 60);
}
