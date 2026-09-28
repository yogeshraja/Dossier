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
    this.serverUrl = 'https://dossier-api.rajayogesh49.workers.dev',
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
      final effectiveHasKiosk = isSignUp
          ? result.hasKiosk
          : (result.hasKiosk || state.isSoftwareActivated || state.registeredOperators.isNotEmpty || user.hasKiosk);

      List<KioskOperator> ops = result.operators.isNotEmpty
          ? result.operators
          : (state.registeredOperators.isNotEmpty ? state.registeredOperators : <KioskOperator>[]);

      KioskOperator? adminOp = result.operators.isNotEmpty
          ? result.operators.first
          : (state.adminOperator ??
              (effectiveHasKiosk
                  ? KioskOperator(
                      id: user.id,
                      fullName: user.name,
                      phone: user.phone ?? '',
                      email: user.email,
                      role: OperatorRole.admin,
                      passwordHash: '',
                      pin: '1234',
                      kioskName: 'Main CSC Center',
                      createdAt: DateTime.now(),
                    )
                  : null));

      if (effectiveHasKiosk && adminOp != null && !ops.any((o) => o.id == adminOp.id)) {
        ops = [adminOp, ...ops];
      }

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isSoftwareActivated: effectiveHasKiosk,
        adminOperator: adminOp,
        registeredOperators: ops,
        serverAuthToken: result.token,
        isLoading: false,
        clearErrorMessage: true,
      );

      if (effectiveHasKiosk && adminOp != null) {
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
      userName: state.user?.name,
      userPhone: state.user?.phone,
      userEmail: state.user?.email,
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

  /// Provision a new desk operator (Admin only)
  Future<bool> addOperator({
    required String name,
    required String pin,
    OperatorRole role = OperatorRole.operator,
    String? phone,
    String? email,
    String? adminPin,
  }) async {
    // 1. Verify admin authorization
    final isAdmin = state.currentOperator?.role == OperatorRole.admin || state.user?.role == 'admin';
    if (!isAdmin) {
      final inputAdminPin = adminPin?.trim() ?? '';
      final expectedPin = state.adminOperator?.pin ?? '1234';
      if (inputAdminPin.isEmpty || inputAdminPin != expectedPin) {
        state = state.copyWith(
          errorMessage: 'Unauthorized: Only the Kiosk Admin can add operators.',
        );
        return false;
      }
    }

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

  /// Update an operator's profile (name, phone, email, role, pin)
  Future<bool> updateOperatorProfile({
    required String operatorId,
    String? fullName,
    String? phone,
    String? email,
    String? newPin,
    OperatorRole? role,
  }) async {
    final cleanName = fullName?.trim();
    final cleanPhone = phone?.trim();
    final cleanEmail = email?.trim();
    final cleanPin = newPin?.trim();

    final opIndex = state.registeredOperators.indexWhere((o) => o.id == operatorId);
    if (opIndex == -1) {
      return false;
    }

    final oldOp = state.registeredOperators[opIndex];
    final updatedOp = oldOp.copyWith(
      fullName: cleanName?.isNotEmpty == true ? cleanName : oldOp.fullName,
      phone: cleanPhone?.isNotEmpty == true ? cleanPhone : oldOp.phone,
      email: cleanEmail?.isNotEmpty == true ? cleanEmail : oldOp.email,
      pin: cleanPin?.isNotEmpty == true && cleanPin!.length == 4 ? cleanPin : oldOp.pin,
      role: role ?? oldOp.role,
    );

    final updatedList = List<KioskOperator>.from(state.registeredOperators);
    updatedList[opIndex] = updatedOp;

    final isCurrent = state.currentOperator?.id == operatorId;
    final isAdmin = state.adminOperator?.id == operatorId;

    state = state.copyWith(
      registeredOperators: updatedList,
      currentOperator: isCurrent ? updatedOp : state.currentOperator,
      adminOperator: isAdmin ? updatedOp : state.adminOperator,
      clearErrorMessage: true,
    );

    return true;
  }

  /// Change quick 4-digit PIN for an operator
  Future<bool> changeOperatorPin({
    required String operatorId,
    required String currentPin,
    required String newPin,
  }) async {
    final cleanCur = currentPin.trim();
    final cleanNew = newPin.trim();

    if (cleanNew.length != 4) {
      state = state.copyWith(errorMessage: 'New PIN must be exactly 4 digits.');
      return false;
    }

    final op = state.registeredOperators.firstWhere(
      (o) => o.id == operatorId,
      orElse: () => state.currentOperator ?? state.registeredOperators.first,
    );

    if (op.pin != cleanCur) {
      state = state.copyWith(errorMessage: 'Current PIN is incorrect.');
      return false;
    }

    return updateOperatorProfile(operatorId: operatorId, newPin: cleanNew);
  }

  /// Delete / Remove a desk operator (Admin only)
  Future<bool> deleteOperator({
    required String operatorId,
  }) async {
    final isAdmin = state.currentOperator?.role == OperatorRole.admin || state.user?.role == 'admin';
    if (!isAdmin) {
      state = state.copyWith(errorMessage: 'Unauthorized: Only administrators can remove operators.');
      return false;
    }

    if (state.adminOperator?.id == operatorId) {
      state = state.copyWith(errorMessage: 'Cannot delete the master admin operator.');
      return false;
    }

    final updatedList = state.registeredOperators.where((o) => o.id != operatorId).toList();
    state = state.copyWith(
      registeredOperators: updatedList,
      clearErrorMessage: true,
    );
    return true;
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

    // Reject suspended operator accounts immediately
    if (op.isSuspended) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Account is suspended${op.suspendedReason != null && op.suspendedReason!.isNotEmpty ? ": ${op.suspendedReason}" : ""}. Please contact your administrator.',
      );
      return false;
    }

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

  /// Delete entire user account and terminate session
  Future<bool> deleteAccount({String? password}) async {
    final user = state.user;
    if (user == null) {
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final success = await _serverAuthApi.deleteAccount(
      userId: user.id,
      token: state.serverAuthToken,
      password: password,
    );

    if (success) {
      // Complete state reset on account deletion
      state = const AuthState();
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete account. Please try again.',
      );
      return false;
    }
  }

  /// Suspend or unsuspend an operator (Admin only)
  Future<bool> suspendOperator({
    required String operatorId,
    required bool suspend,
    String? reason,
  }) async {
    final isAdmin = state.currentOperator?.role == OperatorRole.admin || state.user?.role == 'admin';
    if (!isAdmin) {
      state = state.copyWith(errorMessage: 'Unauthorized: Only administrators can suspend operators.');
      return false;
    }

    if (state.adminOperator?.id == operatorId) {
      state = state.copyWith(errorMessage: 'Cannot suspend the master admin operator.');
      return false;
    }

    final opIndex = state.registeredOperators.indexWhere((o) => o.id == operatorId);
    if (opIndex == -1) return false;

    final oldOp = state.registeredOperators[opIndex];
    final updatedOp = oldOp.copyWith(
      isSuspended: suspend,
      status: suspend ? 'suspended' : 'active',
      suspendedAt: suspend ? DateTime.now() : null,
      suspendedReason: suspend ? (reason ?? 'Suspended by Administrator') : null,
    );

    final updatedList = List<KioskOperator>.from(state.registeredOperators);
    updatedList[opIndex] = updatedOp;

    state = state.copyWith(
      registeredOperators: updatedList,
      clearErrorMessage: true,
    );

    await _serverAuthApi.suspendUser(
      userId: operatorId,
      suspend: suspend,
      reason: reason,
      token: state.serverAuthToken,
    );

    return true;
  }

  /// Sign out entire account / user
  void signOut() {
    state = const AuthState();
  }

  /// Send OTP to mobile number via Twilio
  Future<bool> sendOtp(String mobile) async {
    final cleanMobile = mobile.trim();
    if (cleanMobile.replaceAll(RegExp(r'[^\d]'), '').length < 10) {
      state = state.copyWith(errorMessage: 'Please enter a valid 10-digit mobile number.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final res = await _serverAuthApi.sendOtp(mobile: cleanMobile);

    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      return true;
    } else {
      state = state.copyWith(errorMessage: res['error'] as String? ?? 'Failed to send verification SMS.');
      return false;
    }
  }

  /// Verify OTP code for a mobile number and link to current user if logged in
  Future<bool> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final cleanMobile = mobile.trim();
    final cleanOtp = otp.trim();

    if (cleanOtp.length < 4) {
      state = state.copyWith(errorMessage: 'Please enter the verification code.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final userId = state.user?.id;
    final res = await _serverAuthApi.verifyOtp(
      mobile: cleanMobile,
      otp: cleanOtp,
      userId: userId,
    );

    if (res['success'] == true && res['isVerified'] == true) {
      if (state.user != null) {
        final updatedUser = state.user!.copyWith(
          phone: cleanMobile,
          isMobileVerified: true,
        );
        state = state.copyWith(
          user: updatedUser,
          isLoading: false,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
        );
      }
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: res['error'] as String? ?? 'Invalid verification code. Please try again.',
      );
      return false;
    }
  }

  /// Explicitly link and verify mobile for the logged-in user
  Future<bool> linkAndVerifyMobile({
    required String mobile,
    required String otp,
  }) async {
    final user = state.user;
    if (user == null) {
      return verifyOtp(mobile: mobile, otp: otp);
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final res = await _serverAuthApi.linkAndVerifyMobile(
      userId: user.id,
      mobile: mobile,
      otp: otp,
      token: state.serverAuthToken,
    );

    if (res['success'] == true) {
      final updatedUser = user.copyWith(
        phone: mobile.trim(),
        isMobileVerified: true,
      );
      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
        clearErrorMessage: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: res['error'] as String? ?? 'Failed to verify mobile number.',
      );
      return false;
    }
  }

  /// Clear any active error message
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearErrorMessage: true);
    }
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
