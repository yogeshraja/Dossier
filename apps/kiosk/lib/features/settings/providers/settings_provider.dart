import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KioskSettings {
  final ThemeMode themeMode;
  final String currencySymbol;
  final String currencyCode;
  final String kioskName;
  final String kioskAddress;
  final String kioskPhone;
  final String merchantUpiVpa;
  final Set<String> activeCategories;

  const KioskSettings({
    this.themeMode = ThemeMode.dark,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.kioskName = 'Main Market CSC & Cyber Hub',
    this.kioskAddress = 'Shop #4, Near Post Office',
    this.kioskPhone = '+91 98765 43210',
    this.merchantUpiVpa = 'csckiosk@oksbi',
    this.activeCategories = const {'GOVT_SCHEME', 'PRINTING', 'CERTIFICATE', 'UTILITY', 'LEGAL'},
  });

  KioskSettings copyWith({
    ThemeMode? themeMode,
    String? currencySymbol,
    String? currencyCode,
    String? kioskName,
    String? kioskAddress,
    String? kioskPhone,
    String? merchantUpiVpa,
    Set<String>? activeCategories,
  }) {
    return KioskSettings(
      themeMode: themeMode ?? this.themeMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      kioskName: kioskName ?? this.kioskName,
      kioskAddress: kioskAddress ?? this.kioskAddress,
      kioskPhone: kioskPhone ?? this.kioskPhone,
      merchantUpiVpa: merchantUpiVpa ?? this.merchantUpiVpa,
      activeCategories: activeCategories ?? this.activeCategories,
    );
  }
}

class KioskSettingsNotifier extends StateNotifier<KioskSettings> {
  KioskSettingsNotifier() : super(const KioskSettings());

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void updateCurrency(String symbol, String code) {
    state = state.copyWith(currencySymbol: symbol, currencyCode: code);
  }

  void updateKioskInfo({
    required String name,
    required String address,
    required String phone,
    required String upiVpa,
  }) {
    state = state.copyWith(
      kioskName: name,
      kioskAddress: address,
      kioskPhone: phone,
      merchantUpiVpa: upiVpa,
    );
  }

  void toggleCategory(String category) {
    final updated = Set<String>.from(state.activeCategories);
    if (updated.contains(category)) {
      if (updated.length > 1) updated.remove(category); // Keep at least 1 category
    } else {
      updated.add(category);
    }
    state = state.copyWith(activeCategories: updated);
  }
}

final kioskSettingsProvider = StateNotifierProvider<KioskSettingsNotifier, KioskSettings>((ref) {
  return KioskSettingsNotifier();
});

// Collapsible Billing Hub State Provider
final isBillingHubExpandedProvider = StateProvider<bool>((ref) => true);
