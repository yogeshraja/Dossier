import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';
import 'package:dossier/features/auth/models/operator_model.dart';

/// Email and Password Authentication Strategy
class EmailPasswordAuthStrategy extends BaseAuthStrategy {
  final String email;
  final String password;
  final String? name;
  final http.Client? client;

  const EmailPasswordAuthStrategy({
    required this.email,
    required this.password,
    this.name,
    this.client,
  });

  @override
  String get strategyId => 'email_password';

  @override
  String get displayName => 'Email & Password';

  @override
  AuthProviderType get providerType => AuthProviderType.email;

  @override
  String? validate({bool isSignUp = false}) {
    if (isSignUp && (name == null || name!.trim().isEmpty)) {
      return 'Please enter your full name.';
    }
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return 'Email address cannot be empty.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      return 'Please enter a valid email address.';
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
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name?.trim().isNotEmpty == true ? name!.trim() : 'Admin';
    final endpoint = isSignUp ? '$baseUrl/api/v1/auth/signup' : '$baseUrl/api/v1/auth/signin';

    final payload = isSignUp
        ? {
            'name': cleanName,
            'email': cleanEmail,
            'password': password.trim(),
            'authProvider': 'email',
          }
        : {
            'identifier': cleanEmail,
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

        final rawOps = data['operators'] as List<dynamic>? ?? [];
        final parsedOps = rawOps.map<KioskOperator>((o) {
          final m = o as Map<String, dynamic>;
          final r = m['role'] == 'admin'
              ? OperatorRole.admin
              : (m['role'] == 'manager' ? OperatorRole.manager : OperatorRole.operator);
          return KioskOperator(
            id: m['id'] as String? ?? 'op-1',
            fullName: m['name'] as String? ?? user.name,
            phone: m['mobile'] as String? ?? '',
            email: m['email'] as String? ?? user.email,
            role: r,
            passwordHash: '',
            pin: m['pin'] as String? ?? '1234',
            kioskName: (data['kiosk'] as Map<String, dynamic>?)?['name'] as String? ?? 'Main Kiosk',
            createdAt: DateTime.now(),
          );
        }).toList();

        return StrategyAuthResult.success(
          user: user,
          token: token,
          hasKiosk: hasKiosk || (!isSignUp && parsedOps.isNotEmpty),
          operators: parsedOps,
          rawData: data,
        );
      } else {
        return StrategyAuthResult.failure(data['error'] as String? ?? 'Authentication failed');
      }
    } catch (_) {
      // Offline fallback: sign-in restores active kiosk, sign-up enters FTUE onboarding
      final isReturningSession = !isSignUp;
      final offlineUser = AuthUser(
        id: 'usr_offline_${cleanEmail.hashCode.abs()}',
        name: cleanName,
        email: cleanEmail,
        provider: AuthProviderType.email,
        role: 'admin',
        hasKiosk: isReturningSession,
      );

      final fallbackOp = KioskOperator(
        id: offlineUser.id,
        fullName: cleanName,
        phone: '',
        email: cleanEmail,
        role: OperatorRole.admin,
        passwordHash: '',
        pin: '1234',
        kioskName: 'Main Kiosk Center',
        createdAt: DateTime.now(),
      );

      return StrategyAuthResult.success(
        user: offlineUser,
        token: 'offline_session_jwt_${DateTime.now().millisecondsSinceEpoch}',
        hasKiosk: isReturningSession,
        operators: isReturningSession ? [fallbackOp] : [],
      );
    }
  }
}
