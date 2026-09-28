import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/email_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/phone_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/google_sso_auth_strategy.dart';

/// Factory class for instantiating and resolving AuthStrategy instances
class AuthStrategyFactory {
  static AuthStrategy createEmailStrategy({
    required String email,
    required String password,
    String? name,
  }) {
    return EmailPasswordAuthStrategy(
      email: email,
      password: password,
      name: name,
    );
  }

  static AuthStrategy createPhoneStrategy({
    required String phone,
    required String password,
    String? name,
  }) {
    return PhonePasswordAuthStrategy(
      phone: phone,
      password: password,
      name: name,
    );
  }

  static AuthStrategy createGoogleStrategy({
    String? mockEmail,
    String? mockName,
  }) {
    return GoogleSsoAuthStrategy(
      mockEmail: mockEmail,
      mockName: mockName,
    );
  }

  static AuthStrategy forProvider(AuthProviderType provider, {
    String? identifier,
    String? password,
    String? name,
  }) {
    switch (provider) {
      case AuthProviderType.email:
        return createEmailStrategy(
          email: identifier ?? '',
          password: password ?? '',
          name: name,
        );
      case AuthProviderType.mobile:
        return createPhoneStrategy(
          phone: identifier ?? '',
          password: password ?? '',
          name: name,
        );
      case AuthProviderType.google:
        return createGoogleStrategy();
      case AuthProviderType.offline:
        return createEmailStrategy(
          email: identifier ?? 'offline@dossier.local',
          password: password ?? '123456',
        );
    }
  }
}
