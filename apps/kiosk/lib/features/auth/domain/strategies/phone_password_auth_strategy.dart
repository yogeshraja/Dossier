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

  @override
  String? validate() {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
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
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    final endpoint = isSignUp ? '$baseUrl/api/v1/auth/signup' : '$baseUrl/api/v1/auth/signin';

    final payload = isSignUp
        ? {
            'name': name?.trim().isNotEmpty == true ? name!.trim() : 'Admin',
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
    } catch (e) {
      return StrategyAuthResult.failure('Network connection error: ${e.toString()}');
    }
  }
}
