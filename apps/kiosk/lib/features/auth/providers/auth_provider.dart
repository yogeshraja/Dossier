import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy_factory.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';

final serverAuthApiServiceProvider = Provider<ServerAuthApiService>((ref) {
  return ServerAuthApiService();
});

class AuthState {
  final AuthUser? user;
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
    this.user,
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
  bool get isUserLoggedIn => isAuthenticated && user != null;

  AuthState copyWith({
    AuthUser? user,
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
    bool clearUser = false,
    bool clearCurrentOperator = false,
    bool clearAdminOperator = false,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
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

  /// 1. User Authentication via Strategy (Email, Phone, Google SSO)
  Future<bool> authenticateWithStrategy(
    AuthStrategy strategy, {
    required bool isSignUp,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final result = await _serverAuthApi.authenticateWithStrategy(
      strategy,
      isSignUp: isSignUp,
    );

    if (result.isSuccess && result.user != null) {
      final user = result.user!;
      final hasKiosk = result.hasKiosk;

      List<KioskOperator> ops = result.operators;
      KioskOperator? adminOp;
      if (hasKiosk && ops.isNotEmpty) {
        adminOp = ops.first;
      }

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isSoftwareActivated: hasKiosk,
        adminOperator: adminOp,
        registeredOperators: ops,
        serverAuthToken: result.token,
        isLoading: false,
        clearErrorMessage: true,
      );

      if (hasKiosk && adminOp != null) {
        _updateOperatorState(adminOp);
      }

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Authentication failed',
      );
      return false;
    }
  }

  /// 2. Kiosk Setup & Product Registration (Software Activation)
  Future<bool> registerKioskAndActivate({
    required String kioskName,
    String? kioskAddress,
    String? merchantUpiVpa,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    final cleanKiosk = kioskName.trim();
    final cleanPin = pin.trim();

    if (cleanKiosk.isEmpty || cleanPin.length != 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kiosk name and 4-digit numeric PIN are required.',
      );
      return false;
    }

    final userId = state.user?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

    final result = await _serverAuthApi.registerKioskAndActivate(
      userId: userId,
      kioskName: cleanKiosk,
      kioskAddress: kioskAddress,
      merchantUpiVpa: merchantUpiVpa,
      pin: cleanPin,
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
        isLoading: false,
      );

      _updateOperatorState(admin);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ?? 'Failed to register kiosk and activate software.',
      );
      return false;
    }
  }

  /// Convenience Sign-In with credentials
  Future<bool> signInWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim().toLowerCase().replaceAll(RegExp(r'[\s\-+]'), '');
    final cleanPwd = password.trim();

    // 1. Check local registered operators if software is active
    if (state.registeredOperators.isNotEmpty) {
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
    }

    final strategy = identifier.contains('@')
        ? AuthStrategyFactory.createEmailStrategy(email: identifier, password: password)
        : AuthStrategyFactory.createPhoneStrategy(phone: identifier, password: password);

    return authenticateWithStrategy(strategy, isSignUp: false);
  }

  /// Convenience Sign-Up (Master Activation / Direct Registration)
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

  /// Backward compatible master activation
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

      final authUser = AuthUser(
        id: admin.id,
        name: admin.fullName,
        email: admin.email,
        phone: admin.phone,
        hasKiosk: true,
        role: 'admin',
      );

      state = state.copyWith(
        user: authUser,
        isAuthenticated: true,
        isSoftwareActivated: true,
        adminOperator: admin,
        registeredOperators: operators,
        serverAuthToken: result.token,
        isOfflineMode: result.isOfflineFallback,
        isServerConnected: !result.isOfflineFallback,
        isLoading: false,
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

  /// Provision a new desk operator
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

    final result = await _serverAuthApi.createOperatorOnServer(
      authToken: token,
      name: cleanName,
      pin: cleanPin,
      role: role,
      phone: phone,
      email: email,
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

  /// Operator Shift Login (Select Operator + Enter 4-digit PIN)
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

  /// Sign out entire account / user
  void signOut() {
    state = const AuthState();
  }

  void _updateOperatorState(KioskOperator operator) {
    final updatedList = state.registeredOperators.map((o) {
      return o.id == operator.id ? operator : o;
    }).toList();

    if (!updatedList.any((o) => o.id == operator.id)) {
      updatedList.add(operator);
    }

    state = state.copyWith(
      currentOperator: operator,
      adminOperator: operator.role == OperatorRole.admin ? operator : state.adminOperator,
      registeredOperators: updatedList,
      isAuthenticated: true,
      isPinLocked: false,
      isLoading: false,
      clearErrorMessage: true,
    );

    // Sync kiosk business settings
    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: operator.kioskName,
          address: operator.kioskAddress ?? 'Local CSC Center',
          phone: operator.phone,
          upiVpa: operator.merchantUpiVpa ?? 'csckiosk@oksbi',
        );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final serverApi = ref.watch(serverAuthApiServiceProvider);
  return AuthNotifier(ref, serverApi);
});
