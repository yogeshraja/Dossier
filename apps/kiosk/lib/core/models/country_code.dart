/// Standardized Country Code Model with Dial Code, Flag Emoji & Phone Validation
class CountryCode {
  final String code; // ISO 3166-1 alpha-2 (e.g. 'IN', 'US', 'GB')
  final String name; // e.g. 'India', 'United States'
  final String dialCode; // e.g. '+91', '+1', '+44'
  final String flag; // Unicode Flag Emoji (e.g. '🇮🇳', '🇺🇸')
  final int minDigits;
  final int maxDigits;
  final String example;

  const CountryCode({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    this.minDigits = 7,
    this.maxDigits = 15,
    this.example = '9876543210',
  });

  String formatFullNumber(String rawDigits) {
    final trimmed = rawDigits.trim();
    if (trimmed.startsWith('+')) {
      final clean = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
      return clean;
    }
    final cleanDigits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    final cleanDial = dialCode.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanDigits.startsWith(cleanDial.replaceAll('+', ''))) {
      return '+$cleanDigits';
    }
    return '$cleanDial$cleanDigits';
  }

  static const CountryCode defaultCountry = CountryCode(
    code: 'IN',
    name: 'India',
    dialCode: '+91',
    flag: '🇮🇳',
    minDigits: 10,
    maxDigits: 10,
    example: '9876543210',
  );

  static const List<CountryCode> all = [
    CountryCode(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳', minDigits: 10, maxDigits: 10, example: '9876543210'),
    CountryCode(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸', minDigits: 10, maxDigits: 10, example: '4155552671'),
    CountryCode(code: 'GB', name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧', minDigits: 10, maxDigits: 11, example: '7911123456'),
    CountryCode(code: 'CA', name: 'Canada', dialCode: '+1', flag: '🇨🇦', minDigits: 10, maxDigits: 10, example: '6045551234'),
    CountryCode(code: 'AE', name: 'United Arab Emirates', dialCode: '+971', flag: '🇦🇪', minDigits: 9, maxDigits: 9, example: '501234567'),
    CountryCode(code: 'SA', name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦', minDigits: 9, maxDigits: 9, example: '512345678'),
    CountryCode(code: 'SG', name: 'Singapore', dialCode: '+65', flag: '🇸🇬', minDigits: 8, maxDigits: 8, example: '81234567'),
    CountryCode(code: 'MY', name: 'Malaysia', dialCode: '+60', flag: '🇲🇾', minDigits: 9, maxDigits: 10, example: '123456789'),
    CountryCode(code: 'AU', name: 'Australia', dialCode: '+61', flag: '🇦🇺', minDigits: 9, maxDigits: 9, example: '412345678'),
    CountryCode(code: 'DE', name: 'Germany', dialCode: '+49', flag: '🇩🇪', minDigits: 10, maxDigits: 11, example: '15112345678'),
    CountryCode(code: 'FR', name: 'France', dialCode: '+33', flag: '🇫🇷', minDigits: 9, maxDigits: 9, example: '612345678'),
    CountryCode(code: 'BD', name: 'Bangladesh', dialCode: '+880', flag: '🇧🇩', minDigits: 10, maxDigits: 10, example: '1712345678'),
    CountryCode(code: 'NP', name: 'Nepal', dialCode: '+977', flag: '🇳🇵', minDigits: 10, maxDigits: 10, example: '9812345678'),
    CountryCode(code: 'LK', name: 'Sri Lanka', dialCode: '+94', flag: '🇱🇰', minDigits: 9, maxDigits: 9, example: '712345678'),
    CountryCode(code: 'NG', name: 'Nigeria', dialCode: '+234', flag: '🇳🇬', minDigits: 10, maxDigits: 10, example: '8021234567'),
    CountryCode(code: 'ZA', name: 'South Africa', dialCode: '+27', flag: '🇿🇦', minDigits: 9, maxDigits: 9, example: '711234567'),
    CountryCode(code: 'PH', name: 'Philippines', dialCode: '+63', flag: '🇵🇭', minDigits: 10, maxDigits: 10, example: '9171234567'),
    CountryCode(code: 'ID', name: 'Indonesia', dialCode: '+62', flag: '🇮🇩', minDigits: 9, maxDigits: 12, example: '81234567890'),
    CountryCode(code: 'KE', name: 'Kenya', dialCode: '+254', flag: '🇰🇪', minDigits: 9, maxDigits: 9, example: '712345678'),
    CountryCode(code: 'BR', name: 'Brazil', dialCode: '+55', flag: '🇧🇷', minDigits: 10, maxDigits: 11, example: '11912345678'),
    CountryCode(code: 'JP', name: 'Japan', dialCode: '+81', flag: '🇯🇵', minDigits: 10, maxDigits: 10, example: '9012345678'),
    CountryCode(code: 'KR', name: 'South Korea', dialCode: '+82', flag: '🇰🇷', minDigits: 9, maxDigits: 10, example: '1012345678'),
    CountryCode(code: 'NZ', name: 'New Zealand', dialCode: '+64', flag: '🇳🇿', minDigits: 8, maxDigits: 10, example: '211234567'),
    CountryCode(code: 'QA', name: 'Qatar', dialCode: '+974', flag: '🇶🇦', minDigits: 8, maxDigits: 8, example: '33123456'),
    CountryCode(code: 'KW', name: 'Kuwait', dialCode: '+965', flag: '🇰🇼', minDigits: 8, maxDigits: 8, example: '91234567'),
    CountryCode(code: 'OM', name: 'Oman', dialCode: '+968', flag: '🇴🇲', minDigits: 8, maxDigits: 8, example: '91234567'),
    CountryCode(code: 'BH', name: 'Bahrain', dialCode: '+973', flag: '🇧🇭', minDigits: 8, maxDigits: 8, example: '36123456'),
  ];

  static CountryCode findByCode(String code) {
    final upper = code.trim().toUpperCase();
    return all.firstWhere(
      (c) => c.code == upper,
      orElse: () => defaultCountry,
    );
  }

  static CountryCode findByDialCode(String dialCode) {
    final clean = dialCode.trim();
    return all.firstWhere(
      (c) => c.dialCode == clean || c.dialCode.replaceAll('+', '') == clean.replaceAll('+', ''),
      orElse: () => defaultCountry,
    );
  }

  static CountryCode detectFromPhoneString(String phone) {
    final clean = phone.trim();
    if (clean.startsWith('+')) {
      for (final c in all) {
        if (clean.startsWith(c.dialCode)) {
          return c;
        }
      }
    }
    return defaultCountry;
  }
}
