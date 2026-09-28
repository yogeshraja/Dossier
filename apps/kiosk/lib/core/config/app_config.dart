import 'package:flutter/foundation.dart';

/// Centralized Application Configuration
/// Monorepo: Dossier Kiosk Client
///
/// Supports runtime & compile-time overrides via `--dart-define`:
/// E.g. `flutter run --dart-define=API_BASE_URL=https://my-api.com --dart-define=OTP_LENGTH=6`
class AppConfig {
  AppConfig._();

  // -------------------------------------------------------------
  // API & Server Configuration
  // -------------------------------------------------------------
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dossier-api.rajayogesh49.workers.dev',
  );

  static const int connectTimeoutSeconds = int.fromEnvironment(
    'CONNECT_TIMEOUT_SEC',
    defaultValue: 15,
  );

  static const int receiveTimeoutSeconds = int.fromEnvironment(
    'RECEIVE_TIMEOUT_SEC',
    defaultValue: 15,
  );

  static const int syncIntervalSeconds = int.fromEnvironment(
    'SYNC_INTERVAL_SEC',
    defaultValue: 60,
  );

  static const int maxRetryAttempts = int.fromEnvironment(
    'MAX_RETRY_ATTEMPTS',
    defaultValue: 3,
  );

  // -------------------------------------------------------------
  // Application Metadata
  // -------------------------------------------------------------
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Dossier',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.3.0',
  );

  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '1',
  );

  static const String appTagline = String.fromEnvironment(
    'APP_TAGLINE',
    defaultValue: 'Offline-First CRM, Kiosk Vault & Touch POS',
  );

  // -------------------------------------------------------------
  // Locale & Financial Formatting
  // -------------------------------------------------------------
  static const String defaultCurrencySymbol = String.fromEnvironment(
    'CURRENCY_SYMBOL',
    defaultValue: '₹',
  );

  static const String defaultCurrencyCode = String.fromEnvironment(
    'CURRENCY_CODE',
    defaultValue: 'INR',
  );

  static const String defaultLocale = String.fromEnvironment(
    'DEFAULT_LOCALE',
    defaultValue: 'en_IN',
  );

  static const String _defaultGstRateStr = String.fromEnvironment(
    'DEFAULT_GST_RATE',
    defaultValue: '18.0',
  );

  static double get defaultGstRate => double.tryParse(_defaultGstRateStr) ?? 18.0;

  // -------------------------------------------------------------
  // Security & Authentication Policy
  // -------------------------------------------------------------
  static const int otpLength = int.fromEnvironment(
    'OTP_LENGTH',
    defaultValue: 6,
  );

  static const int pinLength = int.fromEnvironment(
    'PIN_LENGTH',
    defaultValue: 4,
  );

  static const int otpResendCooldownSeconds = int.fromEnvironment(
    'OTP_RESEND_COOLDOWN_SEC',
    defaultValue: 30,
  );

  static const String mockOtpCode = String.fromEnvironment(
    'MOCK_OTP_CODE',
    defaultValue: '123456',
  );

  static const String mockPinCode = String.fromEnvironment(
    'MOCK_PIN_CODE',
    defaultValue: '1234',
  );

  static const int minMobileDigits = int.fromEnvironment(
    'MIN_MOBILE_DIGITS',
    defaultValue: 10,
  );

  static const String defaultCountryDialCode = String.fromEnvironment(
    'DEFAULT_COUNTRY_DIAL_CODE',
    defaultValue: '+91',
  );

  // -------------------------------------------------------------
  // Environment Flags
  // -------------------------------------------------------------
  static const bool isDevMode = bool.fromEnvironment(
    'DEV_MODE',
    defaultValue: kDebugMode,
  );

  static const bool enableOfflineSync = bool.fromEnvironment(
    'ENABLE_OFFLINE_SYNC',
    defaultValue: true,
  );

  static const bool enableThermalPrinting = bool.fromEnvironment(
    'ENABLE_THERMAL_PRINTING',
    defaultValue: true,
  );
}
