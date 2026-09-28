import 'package:http/http.dart' as http;
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/models/operator_model.dart';

/// Result envelope for strategy-based authentication
class StrategyAuthResult {
  final bool isSuccess;
  final AuthUser? user;
  final String? token;
  final bool hasKiosk;
  final String? errorMessage;
  final Map<String, dynamic>? rawData;
  final List<KioskOperator> operators;

  const StrategyAuthResult({
    required this.isSuccess,
    this.user,
    this.token,
    this.hasKiosk = false,
    this.errorMessage,
    this.rawData,
    this.operators = const [],
  });

  factory StrategyAuthResult.success({
    required AuthUser user,
    required String token,
    bool hasKiosk = false,
    Map<String, dynamic>? rawData,
    List<KioskOperator> operators = const [],
  }) {
    return StrategyAuthResult(
      isSuccess: true,
      user: user,
      token: token,
      hasKiosk: hasKiosk,
      rawData: rawData,
      operators: operators,
    );
  }

  factory StrategyAuthResult.failure(String message) {
    return StrategyAuthResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Abstract base interface for all authentication strategies
abstract class AuthStrategy {
  /// Unique identifier of the strategy (e.g., 'email_password', 'mobile_password', 'google_sso')
  String get strategyId;

  /// Display name of the strategy
  String get displayName;

  /// Provider type associated with this strategy
  AuthProviderType get providerType;

  /// Execute authentication against remote server or local engine
  Future<StrategyAuthResult> authenticate({
    required String baseUrl,
    required bool isSignUp,
    http.Client? client,
  });
}

/// Base abstract class providing common template methods, validation, and error parsing
abstract class BaseAuthStrategy implements AuthStrategy {
  const BaseAuthStrategy();

  /// Validate inputs prior to dispatching network requests
  String? validate();

  /// Template method executing validation followed by provider-specific implementation
  @override
  Future<StrategyAuthResult> authenticate({
    required String baseUrl,
    required bool isSignUp,
    http.Client? client,
  }) async {
    final validationError = validate();
    if (validationError != null) {
      return StrategyAuthResult.failure(validationError);
    }

    try {
      return await performAuthentication(baseUrl: baseUrl, isSignUp: isSignUp, client: client);
    } catch (e) {
      return StrategyAuthResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  /// Specific implementation to be provided by subclasses
  Future<StrategyAuthResult> performAuthentication({
    required String baseUrl,
    required bool isSignUp,
    http.Client? client,
  });
}
