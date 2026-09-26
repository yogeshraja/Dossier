import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';

class AuthState {
  final List<KioskOperator> registeredOperators;
  final KioskOperator? currentOperator;
  final bool isAuthenticated;
  final bool isPinLocked;
  final bool isLoading;
  final String? errorMessage;
  final bool rememberMe;

  const AuthState({
    required this.registeredOperators,
    this.currentOperator,
    this.isAuthenticated = false,
    this.isPinLocked = false,
    this.isLoading = false,
    this.errorMessage,
    this.rememberMe = true,
  });

  AuthState copyWith({
    List<KioskOperator>? registeredOperators,
    KioskOperator? currentOperator,
    bool? isAuthenticated,
    bool? isPinLocked,
    bool? isLoading,
    String? errorMessage,
    bool? rememberMe,
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
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref)
      : super(
          AuthState(
            registeredOperators: _defaultSeededOperators,
            currentOperator: null,
            isAuthenticated: false,
          ),
        );

  static final List<KioskOperator> _defaultSeededOperators = [
    KioskOperator(
      id: 'op-admin-001',
      fullName: 'Ramesh Sharma',
      phone: '9876543210',
      email: 'ramesh.csc@dossier.local',
      role: OperatorRole.admin,
      passwordHash: 'admin123',
      pin: '1234',
      kioskName: 'Main Market CSC & Cyber Hub',
      kioskAddress: 'Shop #4, Near Post Office, Main Road',
      merchantUpiVpa: 'csckiosk@oksbi',
      createdAt: DateTime(2026, 1, 1),
      avatarColorIndex: 0,
    ),
    KioskOperator(
      id: 'op-staff-002',
      fullName: 'Priya Verma',
      phone: '9876543211',
      email: 'priya.operator@dossier.local',
      role: OperatorRole.operator,
      passwordHash: 'staff123',
      pin: '5678',
      kioskName: 'Main Market CSC & Cyber Hub',
      kioskAddress: 'Shop #4, Near Post Office, Main Road',
      merchantUpiVpa: 'csckiosk@oksbi',
      createdAt: DateTime(2026, 2, 1),
      avatarColorIndex: 1,
    ),
  ];

  /// Sign in with Phone/Email and Password
  Future<bool> signInWithCredentials({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    await Future.delayed(const Duration(milliseconds: 300)); // Smooth UX transition

    final cleanId = identifier.trim().toLowerCase().replaceAll(RegExp(r'[\s\-+]'), '');
    final cleanPwd = password.trim();

    final matched = state.registeredOperators.where((op) {
      final opPhone = op.phone.replaceAll(RegExp(r'[\s\-+]'), '');
      final opEmail = op.email?.toLowerCase().trim() ?? '';
      final idMatch = opPhone == cleanId || opPhone.endsWith(cleanId) || opEmail == cleanId;
      final pwdMatch = op.passwordHash == cleanPwd;
      return idMatch && pwdMatch;
    }).toList();

    if (matched.isNotEmpty) {
      final operator = matched.first.copyWith(lastLoginAt: DateTime.now());
      _updateOperatorState(operator);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid mobile number/email or password.',
      );
      return false;
    }
  }

  /// Sign in or Quick Unlock with 4-Digit PIN
  Future<bool> signInWithPin({
    required String pin,
    String? operatorId,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    await Future.delayed(const Duration(milliseconds: 200));

    final cleanPin = pin.trim();
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
      // Find operator matching this PIN
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

  /// Register / Sign-Up New Kiosk Operator
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
    await Future.delayed(const Duration(milliseconds: 350));

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

    // Check duplicate phone
    final exists = state.registeredOperators.any(
      (o) => o.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone.replaceAll(RegExp(r'\D'), ''),
    );

    if (exists) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An operator with this phone number already exists.',
      );
      return false;
    }

    const uuid = Uuid();
    final newOperator = KioskOperator(
      id: 'op-${uuid.v4().substring(0, 8)}',
      fullName: cleanName,
      phone: cleanPhone,
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      role: role,
      passwordHash: password.trim(),
      pin: pin.trim(),
      kioskName: cleanKiosk,
      kioskAddress: kioskAddress?.trim(),
      merchantUpiVpa: merchantUpiVpa?.trim().isNotEmpty ?? false ? merchantUpiVpa!.trim() : 'csckiosk@oksbi',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      avatarColorIndex: state.registeredOperators.length % 5,
    );

    final updatedList = [...state.registeredOperators, newOperator];
    state = state.copyWith(
      registeredOperators: updatedList,
    );

    _updateOperatorState(newOperator);
    return true;
  }

  /// Quick Demo / Fast Access Login (e.g. for testing & showcase)
  Future<void> quickDemoLogin({String? operatorId}) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    await Future.delayed(const Duration(milliseconds: 150));

    final target = operatorId != null
        ? state.registeredOperators.firstWhere((o) => o.id == operatorId, orElse: () => state.registeredOperators.first)
        : state.registeredOperators.first;

    final updated = target.copyWith(lastLoginAt: DateTime.now());
    _updateOperatorState(updated);
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
    // Update Kiosk Settings in Sync with Operator's Center Details
    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: operator.kioskName,
          address: operator.kioskAddress ?? 'Shop #4, Near Post Office',
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
  return AuthNotifier(ref);
});
