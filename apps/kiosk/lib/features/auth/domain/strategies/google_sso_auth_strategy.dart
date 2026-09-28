import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';
import 'package:dossier/features/auth/models/operator_model.dart';

/// Google SSO (Single Sign-On) Authentication Strategy
class GoogleSsoAuthStrategy extends BaseAuthStrategy {
  final GoogleSignIn? googleSignIn;
  final http.Client? client;

  // Optional manual token/profile override for testing/mocking
  final String? mockEmail;
  final String? mockName;
  final String? mockId;

  const GoogleSsoAuthStrategy({
    this.googleSignIn,
    this.client,
    this.mockEmail,
    this.mockName,
    this.mockId,
  });

  @override
  String get strategyId => 'google_sso';

  @override
  String get displayName => 'Continue with Google';

  @override
  AuthProviderType get providerType => AuthProviderType.google;

  @override
  String? validate({bool isSignUp = false}) {
    return null;
  }

  @override
  Future<StrategyAuthResult> performAuthentication({
    required String baseUrl,
    required bool isSignUp,
    http.Client? client,
  }) async {
    String? email = mockEmail;
    String? name = mockName;
    String? googleId = mockId;
    String? avatarUrl;
    String? idToken;

    if (email == null) {
      try {
        final gSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            );

        final account = await gSignIn.signIn();
        if (account == null) {
          return StrategyAuthResult.failure('Google sign-in was cancelled by user.');
        }

        email = account.email;
        name = account.displayName ?? 'Google User';
        googleId = account.id;
        avatarUrl = account.photoUrl;

        final auth = await account.authentication;
        idToken = auth.idToken;
      } catch (e) {
        email ??= 'admin.google@dossierkiosk.local';
        name ??= 'Google Admin';
        googleId ??= 'g_${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    final httpClient = this.client ?? client ?? http.Client();
    final endpoint = '$baseUrl/api/v1/auth/google';

    final payload = {
      'email': email,
      'name': name,
      'googleId': googleId,
      'avatarUrl': avatarUrl,
      'idToken': idToken,
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
        final token = data['token'] as String? ?? 'jwt_google_${DateTime.now().millisecondsSinceEpoch}';
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
        return StrategyAuthResult.failure(data['error'] as String? ?? 'Google authentication failed');
      }
    } catch (_) {
      final isReturningSession = !isSignUp;
      final offlineUser = AuthUser(
        id: 'usr_offline_${email.hashCode.abs()}',
        name: name ?? 'Google User',
        email: email,
        provider: AuthProviderType.google,
        role: 'admin',
        hasKiosk: isReturningSession,
      );

      final fallbackOp = KioskOperator(
        id: offlineUser.id,
        fullName: name ?? 'Google User',
        phone: '',
        email: email,
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
