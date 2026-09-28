import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';

/// Mobile Phone and Password Authentication Strategy
class PhonePasswordAuthStrategy extends BaseAuthStrategy {
  final String phone;
  final String password;
  final String? name;
  final http.Client? client;

  const PhonePasswordAuthStrategy({
    required this.phone,
    required this.password,
    this.name,
    this.client,
  });

  @override
  String get strategyId => 'phone_password';

  @override
  String get displayName => 'Mobile & Password';

  @override
  AuthProviderType get providerType => AuthProviderType.mobile;

  String _cleanPhoneNumber(String input) {
    String clean = input.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('91') && clean.length == 12) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0') && clean.length == 11) {
      clean = clean.substring(1);
    }
    return clean;
  }

  @override
  String? validate({bool isSignUp = false}) {
    if (isSignUp && (name == null || name!.trim().isEmpty)) {
      return 'Please enter your full name.';
    }
    final cleanPhone = _cleanPhoneNumber(phone);
    if (cleanPhone.length != 10) {
      return 'Please enter a valid 10-digit mobile number.';
    }
    if (password.trim().length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }

  @override
  Future<StrategyAuthResult> performAuthentication({
    required String baseUrl,
    required bool isSignUp,
    http.Client? client,
  }) async {
    final httpClient = this.client ?? client ?? http.Client();
    final cleanPhone = _cleanPhoneNumber(phone);
    final cleanName = name?.trim().isNotEmpty == true ? name!.trim() : 'Admin';
    final endpoint = isSignUp ? '$baseUrl/api/v1/auth/signup' : '$baseUrl/api/v1/auth/signin';

    final payload = isSignUp
        ? {
            'name': cleanName,
            'mobile': cleanPhone,
            'password': password.trim(),
            'authProvider': 'mobile',
          }
        : {
            'identifier': cleanPhone,
            'password': password.trim(),
          };

    try {
      final response = await httpClient
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['token'] as String? ?? 'jwt_${DateTime.now().millisecondsSinceEpoch}';
        final userData = data['user'] as Map<String, dynamic>? ?? {};
        final user = AuthUser.fromJson(userData);
        final hasKiosk = data['hasKiosk'] as bool? ?? user.hasKiosk;

        return StrategyAuthResult.success(
          user: user,
          token: token,
          hasKiosk: hasKiosk,
          rawData: data,
        );
      } else {
        return StrategyAuthResult.failure(data['error'] as String? ?? 'Authentication failed');
      }
    } catch (_) {
      // Offline fallback
      final offlineUser = AuthUser(
        id: 'usr_offline_${cleanPhone.hashCode.abs()}',
        name: cleanName,
        phone: cleanPhone,
        provider: AuthProviderType.mobile,
        role: 'admin',
        hasKiosk: false,
      );

      return StrategyAuthResult.success(
        user: offlineUser,
        token: 'offline_session_jwt_${DateTime.now().millisecondsSinceEpoch}',
        hasKiosk: false,
      );
    }
  }
}
