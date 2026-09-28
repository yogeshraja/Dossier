import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';

final serverAuthApiServiceProvider = Provider<ServerAuthApiService>((ref) {
  return ServerAuthApiService();
});

class AuthState {
  final bool isSoftwareActivated;
  final KioskOperator? adminOperator;
  final List<KioskOperator> registeredOperators;
  final KioskOperator? currentOperator;
  final bool isAuthenticated;
  final bool isPinLocked;
  final bool isLoading;
  final String? errorMessage;
  final bool rememberMe;
  final String? serverAuthToken;
  final bool isServerConnected;
  final bool isOfflineMode;
  final String serverUrl;

  const AuthState({
    this.isSoftwareActivated = false,
    this.adminOperator,
    this.registeredOperators = const [],
    this.currentOperator,
    this.isAuthenticated = false,
    this.isPinLocked = false,
    this.isLoading = false,
    this.errorMessage,
    this.rememberMe = true,
    this.serverAuthToken,
    this.isServerConnected = true,
    this.isOfflineMode = false,
    this.serverUrl = 'https://api.dossier.app',
  });

  bool get hasRegisteredOperators => registeredOperators.isNotEmpty;

  AuthState copyWith({
    bool? isSoftwareActivated,
    KioskOperator? adminOperator,
    List<KioskOperator>? registeredOperators,
    KioskOperator? currentOperator,
    bool? isAuthenticated,
    bool? isPinLocked,
    bool? isLoading,
    String? errorMessage,
    bool? rememberMe,
    String? serverAuthToken,
    bool? isServerConnected,
    bool? isOfflineMode,
    String? serverUrl,
    bool clearCurrentOperator = false,
    bool clearAdminOperator = false,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      isSoftwareActivated: isSoftwareActivated ?? this.isSoftwareActivated,
      adminOperator: clearAdminOperator ? null : (adminOperator ?? this.adminOperator),
      registeredOperators: registeredOperators ?? this.registeredOperators,
      currentOperator: clearCurrentOperator ? null : (currentOperator ?? this.currentOperator),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isPinLocked: isPinLocked ?? this.isPinLocked,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      rememberMe: rememberMe ?? this.rememberMe,
      serverAuthToken: serverAuthToken ?? this.serverAuthToken,
      isServerConnected: isServerConnected ?? this.isServerConnected,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final ServerAuthApiService _serverAuthApi;

  AuthNotifier(this.ref, this._serverAuthApi)
      : super(
          const AuthState(
            isSoftwareActivated: false,
            registeredOperators: [],
            currentOperator: null,
            isAuthenticated: false,
          ),
        );

  /// Configure custom server endpoint URL
  void setServerUrl(String url) {
    state = state.copyWith(serverUrl: url.trim());
  }

  /// Ping server to test connectivity
  Future<bool> checkServerConnection() async {
    final connected = await _serverAuthApi.checkServerHealth();
    state = state.copyWith(isServerConnected: connected);
    return connected;
  }

  /// Step 1: Admin Software Activation (Sign-Up / Sign-In with Remote Server)
  Future<bool> activateSoftware({
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
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanPhone = phone.trim();
    final cleanName = adminName.trim();
    final cleanKiosk = kioskName.trim();

    if (cleanPhone.isEmpty || cleanName.isEmpty || cleanKiosk.isEmpty || password.isEmpty || pin.length != 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter all required information with a 4-digit numeric PIN.',
      );
      return false;
    }

    final result = await _serverAuthApi.activateSoftware(
      adminName: cleanName,
      phone: cleanPhone,
      email: email,
      password: password,
      pin: pin,
      kioskName: cleanKiosk,
      kioskAddress: kioskAddress,
      merchantUpiVpa: merchantUpiVpa,
      isNewRegistration: isNewRegistration,
    );

    if (result.isSuccess && result.operator != null) {
      final admin = result.operator!;
      final operators = result.operators.isNotEmpty ? result.operators : [admin];

      state = state.copyWith(
        isSoftwareActivated: true,
        adminOperator: admin,
        registeredOperators: operators,
        serverAuthToken: result.token,
        isOfflineMode: result.isOfflineFallback,
        isServerConnected: !result.isOfflineFallback,
      );

      _updateOperatorState(admin);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Failed to activate software with server.',
      );
      return false;
    }
  }

  /// Step 2: Provision a new desk operator on server & local cache (Admin only)
  Future<bool> addOperator({
    required String name,
    required String pin,
    OperatorRole role = OperatorRole.operator,
    String? phone,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanName = name.trim();
    final cleanPin = pin.trim();

    if (cleanName.length < 2 || cleanPin.length != 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Operator name (min 2 chars) and 4-digit PIN are required.',
      );
      return false;
    }

    final token = state.serverAuthToken ?? 'offline-token';
    final kioskName = state.adminOperator?.kioskName ?? 'Dossier Kiosk';

    final result = await _serverAuthApi.createOperatorOnServer(
      token: token,
      name: cleanName,
      pin: cleanPin,
      role: role,
      phone: phone,
      email: email,
      kioskName: kioskName,
    );

    if (result.isSuccess && result.operator != null) {
      final newOp = result.operator!;
      final updatedList = [...state.registeredOperators, newOp];

      state = state.copyWith(
        registeredOperators: updatedList,
        isLoading: false,
        clearErrorMessage: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Failed to create operator on server.',
      );
      return false;
    }
  }

  /// Step 3: Operator Shift Login (Select Operator + Enter 4-digit PIN)
  Future<bool> loginOperatorWithPin({
    required String operatorId,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanPin = pin.trim();
    final op = state.registeredOperators.firstWhere(
      (o) => o.id == operatorId,
      orElse: () => state.registeredOperators.isNotEmpty
          ? state.registeredOperators.first
          : (state.adminOperator ??
              KioskOperator(
                id: 'op-default',
                fullName: 'Default Operator',
                phone: '',
                role: OperatorRole.operator,
                passwordHash: '',
                pin: '1234',
                kioskName: 'Dossier Kiosk',
                createdAt: DateTime.now(),
              )),
    );

    // 1. Verify locally
    if (op.pin == cleanPin) {
      final updatedOp = op.copyWith(lastLoginAt: DateTime.now());
      _updateOperatorState(updatedOp);

      // Async server notification
      _serverAuthApi.operatorLogin(operatorId: op.id, pin: cleanPin).ignore();
      return true;
    }

    // 2. Fallback to server verification
    final result = await _serverAuthApi.operatorLogin(operatorId: operatorId, pin: cleanPin);
    if (result.isSuccess && result.operator != null) {
      _updateOperatorState(result.operator!);
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Incorrect 4-digit PIN for ${op.fullName}.',
    );
    return false;
  }

  /// Convenience Sign-In for Admin / Operator with Credentials
  Future<bool> signInWithCredentials({
    required String identifier,
    required String password,
  }) async {
    if (!state.isSoftwareActivated) {
      return activateSoftware(
        adminName: 'Admin',
        phone: identifier,
        email: identifier.contains('@') ? identifier : null,
        password: password,
        pin: password.length == 4 && RegExp(r'^\d{4}$').hasMatch(password) ? password : '1234',
        kioskName: 'Dossier Kiosk',
        isNewRegistration: false,
      );
    }

    // If software is already activated, find matching operator
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final cleanId = identifier.trim().toLowerCase().replaceAll(RegExp(r'[\s\-+]'), '');
    final cleanPwd = password.trim();

    final matched = state.registeredOperators.where((op) {
      final opPhone = op.phone.replaceAll(RegExp(r'[\s\-+]'), '');
      final opEmail = op.email?.toLowerCase().trim() ?? '';
      final idMatch = opPhone == cleanId || opPhone.endsWith(cleanId) || opEmail == cleanId;
      final pwdMatch = op.passwordHash == cleanPwd || op.pin == cleanPwd;
      return idMatch && pwdMatch;
    }).toList();

    if (matched.isNotEmpty) {
      final operator = matched.first.copyWith(lastLoginAt: DateTime.now());
      _updateOperatorState(operator);
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Invalid mobile number/email or password/PIN.',
    );
    return false;
  }

  /// Convenience Sign-Up (Master Activation)
  Future<bool> signUp({
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
    return activateSoftware(
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
  }

  /// Lock Session with PIN Screen
  void lockSession() {
    state = state.copyWith(isPinLocked: true);
  }

  /// Unlock Session with PIN
  bool unlockSession(String pin) {
    if (state.currentOperator?.pin == pin.trim()) {
      state = state.copyWith(isPinLocked: false, clearErrorMessage: true);
      return true;
    } else {
      state = state.copyWith(errorMessage: 'Invalid unlock PIN');
      return false;
    }
  }

  /// Switch active operator
  void switchOperator(String operatorId) {
    final op = state.registeredOperators.firstWhere(
      (o) => o.id == operatorId,
      orElse: () => state.registeredOperators.first,
    );
    _updateOperatorState(op);
  }

  /// Sign out active operator shift (returns to Operator Select Screen)
  void logout() {
    state = state.copyWith(
      isAuthenticated: false,
      isPinLocked: false,
      clearCurrentOperator: true,
      clearErrorMessage: true,
    );
  }

  /// Deactivate software completely (returns to Admin Activation screen)
  void resetKioskActivation() {
    state = state.copyWith(
      isSoftwareActivated: false,
      isAuthenticated: false,
      isPinLocked: false,
      serverAuthToken: null,
      clearAdminOperator: true,
      clearCurrentOperator: true,
      registeredOperators: [],
      clearErrorMessage: true,
    );
  }

  void toggleRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void _updateOperatorState(KioskOperator operator) {
    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: operator.kioskName,
          address: operator.kioskAddress ?? '',
          phone: operator.phone,
          upiVpa: operator.merchantUpiVpa ?? 'csckiosk@oksbi',
        );

    state = state.copyWith(
      currentOperator: operator,
      isAuthenticated: true,
      isPinLocked: false,
      isLoading: false,
      clearErrorMessage: true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final serverAuthApi = ref.watch(serverAuthApiServiceProvider);
  return AuthNotifier(ref, serverAuthApi);
});
