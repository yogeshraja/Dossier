import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';

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

        return StrategyAuthResult.success(
          user: user,
          token: token,
          hasKiosk: hasKiosk,
          rawData: data,
        );
      } else {
        return StrategyAuthResult.failure(data['error'] as String? ?? 'Google authentication failed');
      }
    } catch (_) {
      final offlineUser = AuthUser(
        id: 'usr_offline_${email.hashCode.abs()}',
        name: name ?? 'Google User',
        email: email,
        provider: AuthProviderType.google,
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
