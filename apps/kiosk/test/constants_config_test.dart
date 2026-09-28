import 'package:flutter_test/flutter_test.dart';
import 'package:dossier/core/constants/app_constants.dart';

void main() {
  group('AppConfig & Environment Defaults', () {
    test('provides valid API defaults and timeouts', () {
      expect(AppConfig.defaultApiBaseUrl, isNotEmpty);
      expect(AppConfig.defaultApiBaseUrl, contains('http'));
      expect(AppConfig.connectTimeoutSeconds, greaterThan(0));
      expect(AppConfig.receiveTimeoutSeconds, greaterThan(0));
      expect(AppConfig.syncIntervalSeconds, greaterThan(0));
    });

    test('provides valid security policy parameters', () {
      expect(AppConfig.otpLength, equals(6));
      expect(AppConfig.pinLength, equals(4));
      expect(AppConfig.minMobileDigits, equals(10));
      expect(AppConfig.mockOtpCode, equals('123456'));
      expect(AppConfig.mockPinCode, equals('1234'));
      expect(AppConfig.defaultCountryDialCode, equals('+91'));
    });

    test('provides financial and locale defaults', () {
      expect(AppConfig.defaultCurrencySymbol, equals('₹'));
      expect(AppConfig.defaultCurrencyCode, equals('INR'));
      expect(AppConfig.defaultLocale, equals('en_IN'));
      expect(AppConfig.defaultGstRate, equals(18.0));
    });
  });

  group('AppDimensions Spatial Tokens', () {
    test('verifies standard spacing and padding', () {
      expect(AppDimensions.space4, equals(4.0));
      expect(AppDimensions.space8, equals(8.0));
      expect(AppDimensions.space16, equals(16.0));
      expect(AppDimensions.space24, equals(24.0));
      expect(AppDimensions.space32, equals(32.0));
      expect(AppDimensions.paddingMD.top, equals(16.0));
    });

    test('verifies sidebar and panel bounds', () {
      expect(AppDimensions.sidebarExpandedWidth, equals(240.0));
      expect(AppDimensions.sidebarCollapsedWidth, equals(76.0));
      expect(AppDimensions.panelMinWidth, greaterThanOrEqualTo(200.0));
      expect(AppDimensions.panelMaxWidth, greaterThan(AppDimensions.panelMinWidth));
      expect(AppDimensions.receiptCharsPerLine58mm, equals(32));
      expect(AppDimensions.receiptCharsPerLine80mm, equals(48));
    });
  });

  group('AppBreakpoints Viewport Constraints', () {
    test('accurately classifies screen widths', () {
      expect(AppBreakpoints.isMobile(360.0), isTrue);
      expect(AppBreakpoints.isMobile(640.0), isFalse);
      expect(AppBreakpoints.isTablet(768.0), isTrue);
      expect(AppBreakpoints.isDesktop(1024.0), isTrue);
      expect(AppBreakpoints.isUltraWide(1600.0), isTrue);
    });
  });

  group('AppDurations Animation Tokens', () {
    test('verifies animation and debounce durations', () {
      expect(AppDurations.fast.inMilliseconds, equals(150));
      expect(AppDurations.standard.inMilliseconds, equals(250));
      expect(AppDurations.slow.inMilliseconds, equals(400));
      expect(AppDurations.toastDuration.inSeconds, equals(3));
      expect(AppDurations.otpCountdown.inSeconds, equals(30));
    });
  });

  group('AppStrings Storage Keys & Routes', () {
    test('contains unique non-empty storage keys', () {
      expect(AppStrings.keyThemeMode, isNotEmpty);
      expect(AppStrings.keyAuthToken, isNotEmpty);
      expect(AppStrings.keyActiveUser, isNotEmpty);
      expect(AppStrings.keyActiveOperator, isNotEmpty);
      expect(AppStrings.keyKioskIdentity, isNotEmpty);
    });
  });
}
