import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:dossier/features/auth/models/operator_model.dart';

class ServerAuthResult {
  final bool isSuccess;
  final String? token;
  final KioskOperator? operator;
  final List<KioskOperator> operators;
  final String? errorMessage;
  final bool isOfflineFallback;
  final Map<String, dynamic>? tenantSettings;
  final bool isActivated;

  const ServerAuthResult({
    required this.isSuccess,
    this.token,
    this.operator,
    this.operators = const [],
    this.errorMessage,
    this.isOfflineFallback = false,
    this.tenantSettings,
    this.isActivated = false,
  });

  factory ServerAuthResult.success({
    required String token,
    required KioskOperator operator,
    List<KioskOperator> operators = const [],
    Map<String, dynamic>? tenantSettings,
    bool isOfflineFallback = false,
    bool isActivated = true,
  }) {
    return ServerAuthResult(
      isSuccess: true,
      token: token,
      operator: operator,
      operators: operators,
      tenantSettings: tenantSettings,
      isOfflineFallback: isOfflineFallback,
      isActivated: isActivated,
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
/// Handles kiosk software activation, operator management, and desk shift logins.
class ServerAuthApiService {
  final String baseUrl;
  final http.Client _client;

  ServerAuthApiService({
    this.baseUrl = 'https://api.dossier.app',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Activate Software on this Device (Admin Sign-Up or Sign-In)
  Future<ServerAuthResult> activateSoftware({
    required String adminName,
    required String phone,
    String? email,
    required String password,
    required String pin,
    required String kioskName,
    String? kioskAddress,
    String? merchantUpiVpa,
    bool isNewRegistration = false,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = adminName.trim();
    final cleanKiosk = kioskName.trim();

    final payload = {
      'adminName': cleanName,
      'mobile': cleanPhone,
      'email': email?.trim().isNotEmpty ?? false ? email!.trim() : null,
      'password': password.trim(),
      'pin': pin.trim(),
      'kioskName': cleanKiosk,
      'kioskAddress': kioskAddress?.trim(),
      'merchantUpiVpa': merchantUpiVpa?.trim().isNotEmpty ?? false ? merchantUpiVpa!.trim() : 'csckiosk@oksbi',
      'isNewRegistration': isNewRegistration,
      'clientTimestamp': DateTime.now().toIso8601String(),
    };

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/activate');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['activationToken'] as String? ?? 'dossier-jwt-${const Uuid().v4()}';
        final adminData = data['admin'] as Map<String, dynamic>? ?? {};
        final kioskData = data['kiosk'] as Map<String, dynamic>? ?? {};
        final rawOperators = data['operators'] as List<dynamic>? ?? [];

        final adminOperator = KioskOperator(
          id: adminData['id'] as String? ?? 'adm-${const Uuid().v4().substring(0, 8)}',
          fullName: adminData['name'] as String? ?? cleanName,
          phone: adminData['mobile'] as String? ?? cleanPhone,
          email: adminData['email'] as String? ?? email?.trim(),
          role: OperatorRole.admin,
          passwordHash: password.trim(),
          pin: pin.trim(),
          kioskName: kioskData['name'] as String? ?? cleanKiosk,
          kioskAddress: kioskData['address'] as String? ?? kioskAddress?.trim(),
          merchantUpiVpa: kioskData['merchantUpiVpa'] as String? ?? merchantUpiVpa?.trim(),
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        final parsedOperators = rawOperators.map<KioskOperator>((item) {
          final map = item as Map<String, dynamic>;
          final r = map['role'] == 'admin'
              ? OperatorRole.admin
              : (map['role'] == 'manager' ? OperatorRole.manager : OperatorRole.operator);
          return KioskOperator(
            id: map['id'] as String,
            fullName: map['name'] as String? ?? 'Operator',
            phone: map['mobile'] as String? ?? '',
            email: map['email'] as String?,
            role: r,
            passwordHash: '',
            pin: map['pin'] as String? ?? '1234',
            kioskName: cleanKiosk,
            createdAt: DateTime.now(),
          );
        }).toList();

        if (parsedOperators.isEmpty) {
          parsedOperators.add(adminOperator);
        }

        return ServerAuthResult.success(
          token: token,
          operator: adminOperator,
          operators: parsedOperators,
          tenantSettings: kioskData,
          isActivated: true,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMsg = data?['error'] as String? ?? data?['message'] as String? ?? 'Activation failed (${response.statusCode})';
        return ServerAuthResult.failure(errorMsg);
      }
    } catch (e) {
      // Offline fallback: activate locally
      const uuid = Uuid();
      final localAdmin = KioskOperator(
        id: 'adm-${uuid.v4().substring(0, 8)}',
        fullName: cleanName,
        phone: cleanPhone,
        email: email?.trim().isNotEmpty ?? false ? email!.trim() : null,
        role: OperatorRole.admin,
        passwordHash: password.trim(),
        pin: pin.trim(),
        kioskName: cleanKiosk,
        kioskAddress: kioskAddress?.trim(),
        merchantUpiVpa: merchantUpiVpa?.trim().isNotEmpty ?? false ? merchantUpiVpa!.trim() : 'csckiosk@oksbi',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      return ServerAuthResult.success(
        token: 'offline-activation-token-${uuid.v4()}',
        operator: localAdmin,
        operators: [localAdmin],
        isOfflineFallback: true,
        isActivated: true,
      );
    }
  }

  /// Create a new Operator on remote server
  Future<ServerAuthResult> createOperatorOnServer({
    required String token,
    required String name,
    required String pin,
    required OperatorRole role,
    String? phone,
    String? email,
    required String kioskName,
  }) async {
    final payload = {
      'name': name.trim(),
      'pin': pin.trim(),
      'role': role.name,
      'mobile': phone?.trim(),
      'email': email?.trim(),
    };

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/operators');
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final opData = data['operator'] as Map<String, dynamic>? ?? {};

        final newOp = KioskOperator(
          id: opData['id'] as String? ?? 'op-${const Uuid().v4().substring(0, 8)}',
          fullName: opData['name'] as String? ?? name.trim(),
          phone: opData['mobile'] as String? ?? (phone ?? ''),
          email: opData['email'] as String? ?? email,
          role: role,
          passwordHash: '',
          pin: pin.trim(),
          kioskName: kioskName,
          createdAt: DateTime.now(),
        );

        return ServerAuthResult.success(
          token: token,
          operator: newOp,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return ServerAuthResult.failure(data?['error'] as String? ?? 'Failed to create operator on server.');
      }
    } catch (e) {
      // Local fallback
      final localOp = KioskOperator(
        id: 'op-${const Uuid().v4().substring(0, 8)}',
        fullName: name.trim(),
        phone: phone?.trim() ?? '',
        email: email?.trim(),
        role: role,
        passwordHash: '',
        pin: pin.trim(),
        kioskName: kioskName,
        createdAt: DateTime.now(),
      );
      return ServerAuthResult.success(token: token, operator: localOp, isOfflineFallback: true);
    }
  }

  /// Operator Desk Shift Login with PIN
  Future<ServerAuthResult> operatorLogin({
    required String operatorId,
    required String pin,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/operator-login');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'operatorId': operatorId.trim(),
              'pin': pin.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ?? 'op-jwt-${const Uuid().v4()}';
        final opData = data['operator'] as Map<String, dynamic>? ?? {};

        final roleStr = opData['role'] as String? ?? 'operator';
        final role = roleStr == 'admin'
            ? OperatorRole.admin
            : (roleStr == 'manager' ? OperatorRole.manager : OperatorRole.operator);

        final op = KioskOperator(
          id: opData['id'] as String? ?? operatorId,
          fullName: opData['name'] as String? ?? 'Desk Operator',
          phone: opData['mobile'] as String? ?? '',
          email: opData['email'] as String?,
          role: role,
          passwordHash: '',
          pin: pin.trim(),
          kioskName: 'Dossier Kiosk',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );

        return ServerAuthResult.success(token: token, operator: op);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return ServerAuthResult.failure(data?['error'] as String? ?? 'Incorrect PIN');
      }
    } catch (e) {
      return ServerAuthResult.failure('Server offline for operator login', isOffline: true);
    }
  }

  /// Sign up convenience wrapper (calls activateSoftware)
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
  }) =>
      activateSoftware(
        adminName: operatorName,
        phone: phone,
        email: email,
        password: password,
        pin: pin,
        kioskName: kioskName,
        kioskAddress: kioskAddress,
        merchantUpiVpa: merchantUpiVpa,
        isNewRegistration: true,
      );

  /// Sign in convenience wrapper (calls activateSoftware)
  Future<ServerAuthResult> signIn({
    required String identifier,
    required String password,
  }) =>
      activateSoftware(
        adminName: 'Admin',
        phone: identifier,
        email: identifier.contains('@') ? identifier : null,
        password: password,
        pin: password.length == 4 && RegExp(r'^\d{4}$').hasMatch(password) ? password : '1234',
        kioskName: 'Dossier Kiosk',
        isNewRegistration: false,
      );

  /// Verify 4-digit PIN with remote server
  Future<ServerAuthResult> verifyPin({
    required String operatorId,
    required String pin,
  }) async {
    return operatorLogin(operatorId: operatorId, pin: pin);
  }

  /// Ping server to verify API health & connectivity
  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
