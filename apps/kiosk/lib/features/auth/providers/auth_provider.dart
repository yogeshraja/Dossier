import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';

final serverAuthApiServiceProvider = Provider<ServerAuthApiService>((ref) {
  return ServerAuthApiService();
});

class AuthState {
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
    bool clearErrorMessage = false,
  }) {
    return AuthState(
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

  /// Sign in with Phone/Email and Password via Server with Offline Fallback
  Future<bool> signInWithCredentials({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanId = identifier.trim();
    final cleanPwd = password.trim();

    if (cleanId.isEmpty || cleanPwd.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter your mobile number/email and password.',
      );
      return false;
    }

    // 1. Attempt remote server sign-in
    final serverResult = await _serverAuthApi.signIn(
      identifier: cleanId,
      password: cleanPwd,
    );

    if (serverResult.isSuccess && serverResult.operator != null) {
      final serverOp = serverResult.operator!;
      
      // Update local operator cache
      final existingIndex = state.registeredOperators.indexWhere((o) => o.id == serverOp.id || o.phone == serverOp.phone);
      List<KioskOperator> updatedList;
      if (existingIndex >= 0) {
        updatedList = List.from(state.registeredOperators)..[existingIndex] = serverOp;
      } else {
        updatedList = [...state.registeredOperators, serverOp];
      }

      state = state.copyWith(
        registeredOperators: updatedList,
        serverAuthToken: serverResult.token,
        isServerConnected: true,
        isOfflineMode: false,
      );

      _updateOperatorState(serverOp);
      return true;
    }

    // 2. If server was offline or returned offline fallback, authenticate against local cache
    if (serverResult.isOfflineFallback || state.registeredOperators.isNotEmpty) {
      final normalizedId = cleanId.toLowerCase().replaceAll(RegExp(r'[\s\-+]'), '');
      final matched = state.registeredOperators.where((op) {
        final opPhone = op.phone.replaceAll(RegExp(r'[\s\-+]'), '');
        final opEmail = op.email?.toLowerCase().trim() ?? '';
        final idMatch = opPhone == normalizedId || opPhone.endsWith(normalizedId) || opEmail == normalizedId;
        final pwdMatch = op.passwordHash == cleanPwd;
        return idMatch && pwdMatch;
      }).toList();

      if (matched.isNotEmpty) {
        final operator = matched.first.copyWith(lastLoginAt: DateTime.now());
        state = state.copyWith(
          isOfflineMode: true,
          serverAuthToken: state.serverAuthToken ?? 'cached-offline-token',
        );
        _updateOperatorState(operator);
        return true;
      }
    }

    // 3. Failed authentication
    state = state.copyWith(
      isLoading: false,
      errorMessage: serverResult.errorMessage ?? 'Invalid mobile number/email or password.',
    );
    return false;
  }

  /// Sign in or Quick Unlock with 4-Digit PIN
  Future<bool> signInWithPin({
    required String pin,
    String? operatorId,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    await Future.delayed(const Duration(milliseconds: 150));

    final cleanPin = pin.trim();
    if (state.registeredOperators.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No registered operators found.',
      );
      return false;
    }

    KioskOperator? matched;
    if (operatorId != null) {
      final op = state.registeredOperators.firstWhere(
        (o) => o.id == operatorId,
        orElse: () => state.registeredOperators.first,
      );
      if (op.pin == cleanPin) {
        matched = op;
      }
    } else if (state.currentOperator != null) {
      if (state.currentOperator!.pin == cleanPin) {
        matched = state.currentOperator;
      }
    } else {
      final list = state.registeredOperators.where((o) => o.pin == cleanPin).toList();
      if (list.isNotEmpty) {
        matched = list.first;
      }
    }

    if (matched != null) {
      final operator = matched.copyWith(lastLoginAt: DateTime.now());
      _updateOperatorState(operator);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Incorrect 4-digit PIN.',
      );
      return false;
    }
  }

  /// Register / Sign-Up New Kiosk Account on Server
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
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanPhone = phone.trim();
    final cleanName = operatorName.trim();
    final cleanKiosk = kioskName.trim();

    if (cleanPhone.isEmpty || cleanName.isEmpty || cleanKiosk.isEmpty || password.isEmpty || pin.length != 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please fill in all mandatory fields with a valid 4-digit PIN.',
      );
      return false;
    }

    // Call server sign-up endpoint
    final result = await _serverAuthApi.signUp(
      kioskName: cleanKiosk,
      operatorName: cleanName,
      phone: cleanPhone,
      email: email,
      password: password,
      pin: pin,
      role: role,
      merchantUpiVpa: merchantUpiVpa,
      kioskAddress: kioskAddress,
    );

    if (result.isSuccess && result.operator != null) {
      final newOperator = result.operator!;
      final updatedList = [...state.registeredOperators, newOperator];

      state = state.copyWith(
        registeredOperators: updatedList,
        serverAuthToken: result.token,
        isOfflineMode: result.isOfflineFallback,
        isServerConnected: !result.isOfflineFallback,
      );

      _updateOperatorState(newOperator);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Failed to register kiosk account on server.',
      );
      return false;
    }
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

  /// Sign out completely
  void logout() {
    state = state.copyWith(
      isAuthenticated: false,
      isPinLocked: false,
      serverAuthToken: null,
      clearCurrentOperator: true,
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
