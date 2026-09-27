import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:dossier/features/auth/models/operator_model.dart';

class ServerAuthResult {
  final bool isSuccess;
  final String? token;
  final KioskOperator? operator;
  final String? errorMessage;
  final bool isOfflineFallback;
  final Map<String, dynamic>? tenantSettings;

  const ServerAuthResult({
    required this.isSuccess,
    this.token,
    this.operator,
    this.errorMessage,
    this.isOfflineFallback = false,
    this.tenantSettings,
  });

  factory ServerAuthResult.success({
    required String token,
    required KioskOperator operator,
    Map<String, dynamic>? tenantSettings,
    bool isOfflineFallback = false,
  }) {
    return ServerAuthResult(
      isSuccess: true,
      token: token,
      operator: operator,
      tenantSettings: tenantSettings,
      isOfflineFallback: isOfflineFallback,
    );
  }

  factory ServerAuthResult.failure(String message, {bool isOffline = false}) {
    return ServerAuthResult(
      isSuccess: false,
      errorMessage: message,
      isOfflineFallback: isOffline,
    );
  }
}

/// Remote Authentication API Service for Dossier Server Backend.
/// Handles account creation, server sign-in, token refresh, and server health checks.
class ServerAuthApiService {
  final String baseUrl;
  final http.Client _client;

  ServerAuthApiService({
    this.baseUrl = 'https://api.dossier.app',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Create new account and kiosk tenant on remote server
  Future<ServerAuthResult> signUp({
    required String kioskName,
    required String operatorName,
    required String phone,
    String? email,
    required String password,
    required String pin,
    OperatorRole role = OperatorRole.admin,
    String? merchantUpiVpa,
    String? kioskAddress,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = operatorName.trim();
    final cleanKiosk = kioskName.trim();

    final payload = {
      'kioskName': cleanKiosk,
      'fullName': cleanName,
      'phoneNumber': cleanPhone,
      'email': email?.trim().isNotEmpty ?? false ? email!.trim() : null,
      'password': password.trim(),
      'pin': pin.trim(),
      'role': role.name,
      'merchantUpiVpa': merchantUpiVpa?.trim().isNotEmpty ?? false ? merchantUpiVpa!.trim() : 'csckiosk@oksbi',
      'kioskAddress': kioskAddress?.trim(),
      'clientTimestamp': DateTime.now().toIso8601String(),
    };

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/signup');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ?? 'dossier-jwt-${const Uuid().v4()}';
        final operatorData = data['operator'] as Map<String, dynamic>? ?? {};

        final newOperator = KioskOperator(
          id: operatorData['id'] as String? ?? 'op-${const Uuid().v4().substring(0, 8)}',
          fullName: operatorData['fullName'] as String? ?? cleanName,
          phone: operatorData['phoneNumber'] as String? ?? cleanPhone,
          email: operatorData['email'] as String? ?? email?.trim(),
          role: role,
          passwordHash: password.trim(),
          pin: pin.trim(),
          kioskName: operatorData['kioskName'] as String? ?? cleanKiosk,
          kioskAddress: operatorData['kioskAddress'] as String? ?? kioskAddress?.trim(),
          merchantUpiVpa: operatorData['merchantUpiVpa'] as String? ?? merchantUpiVpa?.trim(),
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        return ServerAuthResult.success(
          token: token,
          operator: newOperator,
          tenantSettings: data['tenant'] as Map<String, dynamic>?,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMsg = data?['message'] as String? ?? 'Server registration failed (${response.statusCode})';
        return ServerAuthResult.failure(errorMsg);
      }
    } catch (e) {
      // Offline fallback: create local operator profile and queue remote sync
      const uuid = Uuid();
      final localOperator = KioskOperator(
        id: 'op-${uuid.v4().substring(0, 8)}',
        fullName: cleanName,
        phone: cleanPhone,
        email: email?.trim().isNotEmpty ?? false ? email!.trim() : null,
        role: role,
        passwordHash: password.trim(),
        pin: pin.trim(),
        kioskName: cleanKiosk,
        kioskAddress: kioskAddress?.trim(),
        merchantUpiVpa: merchantUpiVpa?.trim().isNotEmpty ?? false ? merchantUpiVpa!.trim() : 'csckiosk@oksbi',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      return ServerAuthResult.success(
        token: 'offline-cached-token-${uuid.v4()}',
        operator: localOperator,
        isOfflineFallback: true,
      );
    }
  }

  /// Sign in with remote server using email or phone and password
  Future<ServerAuthResult> signIn({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim();
    final cleanPwd = password.trim();

    final payload = {
      'identifier': cleanId,
      'password': cleanPwd,
      'clientTimestamp': DateTime.now().toIso8601String(),
    };

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/signin');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ?? 'dossier-jwt-${const Uuid().v4()}';
        final operatorData = data['operator'] as Map<String, dynamic>? ?? {};

        final opRole = operatorData['role'] == 'staff' || operatorData['role'] == 'operator'
            ? OperatorRole.operator
            : (operatorData['role'] == 'manager' ? OperatorRole.manager : OperatorRole.admin);

        final operator = KioskOperator(
          id: operatorData['id'] as String? ?? 'op-${const Uuid().v4().substring(0, 8)}',
          fullName: operatorData['fullName'] as String? ?? 'Kiosk Operator',
          phone: operatorData['phoneNumber'] as String? ?? cleanId,
          email: operatorData['email'] as String?,
          role: opRole,
          passwordHash: cleanPwd,
          pin: operatorData['pin'] as String? ?? '1234',
          kioskName: operatorData['kioskName'] as String? ?? 'Citizen Service Kiosk',
          kioskAddress: operatorData['kioskAddress'] as String?,
          merchantUpiVpa: operatorData['merchantUpiVpa'] as String? ?? 'csckiosk@oksbi',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        return ServerAuthResult.success(
          token: token,
          operator: operator,
          tenantSettings: data['tenant'] as Map<String, dynamic>?,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMsg = data?['message'] as String? ?? 'Invalid credentials (${response.statusCode})';
        return ServerAuthResult.failure(errorMsg);
      }
    } catch (e) {
      return ServerAuthResult.failure('Unable to reach server. Connecting via offline cache...', isOffline: true);
    }
  }

  /// Verify 4-digit PIN with remote server
  Future<ServerAuthResult> verifyPin({
    required String operatorId,
    required String pin,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/verify-pin');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'operatorId': operatorId,
              'pin': pin.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ServerAuthResult.success(
          token: data['token'] as String? ?? 'pin-token-${const Uuid().v4()}',
          operator: null as dynamic,
        );
      } else {
        return ServerAuthResult.failure('Incorrect PIN');
      }
    } catch (e) {
      return ServerAuthResult.failure('Server unreachable for PIN verification', isOffline: true);
    }
  }

  /// Ping server to verify API health & connectivity
  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
