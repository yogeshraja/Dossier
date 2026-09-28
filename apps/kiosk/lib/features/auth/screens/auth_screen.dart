import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy_factory.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/main.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';

enum AuthMode { signIn, signUp }
enum InputAuthMethod { email, mobile }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Step 1: User Login / Sign-up State
  AuthMode _authMode = AuthMode.signIn;
  InputAuthMethod _authMethod = InputAuthMethod.email;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Step 2: Kiosk Product Registration State
  final _kioskNameCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _merchantUpiCtrl = TextEditingController();
  final _masterPinCtrl = TextEditingController();

  // Step 3: Operator Shift PIN State
  String _enteredPin = '';
  String? _selectedOperatorId;

  // New Operator Dialog State
  final _newOpNameCtrl = TextEditingController();
  final _newOpPinCtrl = TextEditingController();
  final _newOpPhoneCtrl = TextEditingController();
  final _newOpEmailCtrl = TextEditingController();
  OperatorRole _newOpRole = OperatorRole.operator;

  @override
  void initState() {
    super.initState();
    _kioskNameCtrl.text = 'Main CSC Document Center';
    _merchantUpiCtrl.text = 'kiosk@oksbi';
    _masterPinCtrl.text = '1234';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.registeredOperators.isNotEmpty) {
        setState(() {
          _selectedOperatorId = auth.registeredOperators.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _kioskNameCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _merchantUpiCtrl.dispose();
    _masterPinCtrl.dispose();
    _newOpNameCtrl.dispose();
    _newOpPinCtrl.dispose();
    _newOpPhoneCtrl.dispose();
    _newOpEmailCtrl.dispose();
    super.dispose();
  }

  void _onSuccessfulLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const KioskWorkstationHome(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // Handle User Login / Sign-up via Strategy
  Future<void> _handleUserAuth() async {
    final isSignUp = _authMode == AuthMode.signUp;
    final strategy = _authMethod == InputAuthMethod.email
        ? AuthStrategyFactory.createEmailStrategy(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            name: _nameCtrl.text,
          )
        : AuthStrategyFactory.createPhoneStrategy(
            phone: _mobileCtrl.text,
            password: _passwordCtrl.text,
            name: _nameCtrl.text,
          );

    final success = await ref.read(authProvider.notifier).authenticateWithStrategy(
          strategy,
          isSignUp: isSignUp,
        );

    if (success && mounted) {
      final auth = ref.read(authProvider);
      if (auth.isSoftwareActivated) {
        _onSuccessfulLogin();
      }
    }
  }

  // Handle Google SSO
  Future<void> _handleGoogleSso() async {
    final strategy = AuthStrategyFactory.createGoogleStrategy();
    final success = await ref.read(authProvider.notifier).authenticateWithStrategy(
          strategy,
          isSignUp: false,
        );

    if (success && mounted) {
      final auth = ref.read(authProvider);
      if (auth.isSoftwareActivated) {
        _onSuccessfulLogin();
      }
    }
  }

  // Handle Kiosk Registration & Software Activation
  Future<void> _handleKioskRegistration() async {
    final success = await ref.read(authProvider.notifier).registerKioskAndActivate(
          kioskName: _kioskNameCtrl.text,
          kioskAddress: _kioskAddressCtrl.text.isNotEmpty ? _kioskAddressCtrl.text : null,
          merchantUpiVpa: _merchantUpiCtrl.text.isNotEmpty ? _merchantUpiCtrl.text : null,
          pin: _masterPinCtrl.text,
        );

    if (success && mounted) {
      _onSuccessfulLogin();
    }
  }

  // Handle Operator Shift PIN input
  Future<void> _handlePinDigit(String digit) async {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        final auth = ref.read(authProvider);
        final opId = _selectedOperatorId ??
            (auth.registeredOperators.isNotEmpty ? auth.registeredOperators.first.id : 'op-default');

        final success = await ref.read(authProvider.notifier).loginOperatorWithPin(
              operatorId: opId,
              pin: _enteredPin,
            );

        if (success && mounted) {
          _onSuccessfulLogin();
        } else {
          setState(() {
            _enteredPin = '';
          });
        }
      }
    }
  }

  void _handlePinBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _promptAdminAuthorizationThenAddOperator() {
    final adminOp = ref.read(authProvider).adminOperator;
    final adminPin = adminOp?.pin ?? '1234';
    final pinCtrl = TextEditingController();
    String? authError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => DossierDialog(
          title: 'Admin Authorization Required',
          icon: Icons.shield_rounded,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only the Kiosk Administrator (${adminOp?.fullName ?? "Owner"}) can add desk operators. Please enter the Master Admin PIN.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (authError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            authError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                DossierInputField(
                  key: const ValueKey('admin_auth_pin_field'),
                  label: 'Master Admin 4-Digit PIN',
                  hintText: '****',
                  controller: pinCtrl,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_person_rounded, size: 18),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            DossierButton(
              text: 'Verify Admin',
              icon: Icons.verified_user_rounded,
              onPressed: () {
                if (pinCtrl.text.trim() == adminPin) {
                  final verifiedPin = pinCtrl.text.trim();
                  Navigator.pop(ctx);
                  _showAddOperatorDialog(verifiedAdminPin: verifiedPin);
                } else {
                  setDialogState(() {
                    authError = 'Incorrect Admin PIN. Only Admin can add operators.';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOperatorDialog({String? verifiedAdminPin}) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => DossierDialog(
          title: 'Provision New Operator',
          icon: Icons.person_add_alt_1_rounded,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operators are created on the server and cached locally for rapid desk shift logins.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DossierInputField(
                  key: const ValueKey('new_op_name_field'),
                  label: 'Operator Full Name',
                  hintText: 'e.g. Ramesh Kumar',
                  controller: _newOpNameCtrl,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DossierInputField(
                        key: const ValueKey('new_op_pin_field'),
                        label: '4-Digit PIN',
                        hintText: '****',
                        controller: _newOpPinCtrl,
                        prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<OperatorRole>(
                            initialValue: _newOpRole,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: OperatorRole.values.map((r) {
                              return DropdownMenuItem(value: r, child: Text(r.label, style: const TextStyle(fontSize: 12)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => _newOpRole = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DossierInputField(
                  key: const ValueKey('new_op_phone_field'),
                  label: 'Mobile Number (Optional)',
                  hintText: '9876543210',
                  controller: _newOpPhoneCtrl,
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            DossierButton(
              text: 'Create Operator',
              icon: Icons.check_circle_rounded,
              onPressed: () async {
                final success = await ref.read(authProvider.notifier).addOperator(
                      name: _newOpNameCtrl.text,
                      pin: _newOpPinCtrl.text,
                      role: _newOpRole,
                      phone: _newOpPhoneCtrl.text.isNotEmpty ? _newOpPhoneCtrl.text : null,
                      email: _newOpEmailCtrl.text.isNotEmpty ? _newOpEmailCtrl.text : null,
                      adminPin: verifiedAdminPin,
                    );
                if (success && ctx.mounted) {
                  _newOpNameCtrl.clear();
                  _newOpPinCtrl.clear();
                  _newOpPhoneCtrl.clear();
                  _newOpEmailCtrl.clear();
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF090D16), Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1000;
              final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1000;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0),
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1080 : 540),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildBrandingPanel(isDark),
                              ),
                              const SizedBox(width: 48),
                              Expanded(
                                flex: 6,
                                child: _buildActiveCard(auth, isDark),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBrandingHeader(isDark),
                              const SizedBox(height: 24),
                              _buildActiveCard(auth, isDark),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingPanel(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'DOSSIER',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'High-Density Workstation for Cyber Cafes & Service Desks',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Offline-first vault, instant operator PIN shifts, raw ESC/POS thermal printing, and automatic Cloudflare D1 synchronization.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildPillBenefit(Icons.security_rounded, 'Two-Tier Authentication & Activation Gate', isDark),
        const SizedBox(height: 12),
        _buildPillBenefit(Icons.offline_pin_rounded, '100% Offline Local Drift SQLite Vault', isDark),
        const SizedBox(height: 12),
        _buildPillBenefit(Icons.cloud_sync_rounded, 'Seamless Cloudflare D1 Edge Synchronization', isDark),
      ],
    );
  }

  Widget _buildBrandingHeader(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('D', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'DOSSIER',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'High-Density POS & Workstation',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPillBenefit(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF6366F1)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCard(AuthState auth, bool isDark) {
    // Flow 1: Not Logged In -> User Sign-In / Sign-Up (Email, Mobile, Google SSO)
    if (!auth.isUserLoggedIn && !auth.isSoftwareActivated) {
      return _buildUserAuthCard(auth, isDark);
    }

    // Flow 2: User is Logged In, but Kiosk is NOT Registered/Activated -> Kiosk Setup Screen
    if (auth.isUserLoggedIn && !auth.isSoftwareActivated) {
      return _buildKioskSetupCard(auth, isDark);
    }

    // Flow 3: Software is Activated -> Operator Shift PIN Login
    return _buildOperatorShiftCard(auth, isDark);
  }

  // ─────────────────────────────────────────────────────────────
  // 1. User Sign-In / Sign-Up Card (Email, Mobile, Google SSO)
  // ─────────────────────────────────────────────────────────────
  Widget _buildUserAuthCard(AuthState auth, bool isDark) {
    final isSignUp = _authMode == AuthMode.signUp;

    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header & Mode Tabs
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                isSignUp ? 'Create Account' : 'Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              DossierBadge(
                label: auth.isServerConnected ? 'SERVER READY' : 'OFFLINE MODE',
                variant: auth.isServerConnected ? DossierBadgeVariant.success : DossierBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSignUp
                ? 'Sign up to register and activate your kiosk software.'
                : 'Sign in to access your kiosk center and desk operations.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Sign In / Sign Up Segmented Controller
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      setState(() => _authMode = AuthMode.signIn);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _authMode == AuthMode.signIn
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _authMode == AuthMode.signIn
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _authMode == AuthMode.signIn ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref.read(authProvider.notifier).clearError();
                      setState(() => _authMode = AuthMode.signUp);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _authMode == AuthMode.signUp
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _authMode == AuthMode.signUp
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _authMode == AuthMode.signUp ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Method Choice: Email vs Mobile
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Email & Password', style: TextStyle(fontSize: 12)),
                selected: _authMethod == InputAuthMethod.email,
                onSelected: (val) {
                  ref.read(authProvider.notifier).clearError();
                  setState(() => _authMethod = InputAuthMethod.email);
                },
              ),
              ChoiceChip(
                label: const Text('Mobile & Password', style: TextStyle(fontSize: 12)),
                selected: _authMethod == InputAuthMethod.mobile,
                onSelected: (val) {
                  ref.read(authProvider.notifier).clearError();
                  setState(() => _authMethod = InputAuthMethod.mobile);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Error banner
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Form Fields
          if (isSignUp) ...[
            DossierInputField(
              key: const ValueKey('auth_signup_name_field'),
              label: 'Full Name',
              hintText: 'e.g. Ramesh Kumar',
              controller: _nameCtrl,
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
            ),
            const SizedBox(height: 12),
          ],

          if (_authMethod == InputAuthMethod.email)
            DossierInputField(
              key: const ValueKey('auth_email_field'),
              label: 'Email Address',
              hintText: 'admin@csc.in',
              controller: _emailCtrl,
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
              keyboardType: TextInputType.emailAddress,
            )
          else
            DossierInputField(
              key: const ValueKey('auth_mobile_field'),
              label: 'Mobile Number',
              hintText: '9876543210',
              controller: _mobileCtrl,
              prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
              keyboardType: TextInputType.phone,
            ),
          const SizedBox(height: 12),

          DossierInputField(
            key: const ValueKey('auth_password_field'),
            label: 'Password',
            hintText: '••••••••',
            controller: _passwordCtrl,
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
          ),
          const SizedBox(height: 20),

          // Primary CTA Button
          SizedBox(
            width: double.infinity,
            child: DossierButton(
              text: isSignUp ? 'Create Admin Account' : 'Sign In to Dossier',
              icon: isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
              isLoading: auth.isLoading,
              onPressed: _handleUserAuth,
            ),
          ),
          const SizedBox(height: 20),

          // Divider: Or continue with
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Or continue with',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 16),

          // Google SSO Option
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading ? null : _handleGoogleSso,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                width: 18,
                height: 18,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, size: 18, color: Color(0xFF4285F4)),
              ),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Kiosk Setup & Product Registration Card (Once Logged In)
  // ─────────────────────────────────────────────────────────────
  Widget _buildKioskSetupCard(AuthState auth, bool isDark) {
    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Register & Activate Kiosk',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 18),
                tooltip: 'Sign Out Account',
                onPressed: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Authenticated as ${auth.user?.name ?? "Admin"} (${auth.user?.email ?? auth.user?.phone ?? "SSO User"}). Complete product registration to activate features.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Error banner
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          DossierInputField(
            key: const ValueKey('kiosk_setup_name_field'),
            label: 'Kiosk / CSC Business Name',
            hintText: 'e.g. Main CSC Document Center',
            controller: _kioskNameCtrl,
            prefixIcon: const Icon(Icons.store_rounded, size: 18),
          ),
          const SizedBox(height: 12),

          DossierInputField(
            key: const ValueKey('kiosk_setup_address_field'),
            label: 'Center Physical Address',
            hintText: 'Shop #12, Market Road',
            controller: _kioskAddressCtrl,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DossierInputField(
                  key: const ValueKey('kiosk_setup_upi_field'),
                  label: 'Merchant UPI VPA',
                  hintText: 'kiosk@oksbi',
                  controller: _merchantUpiCtrl,
                  prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DossierInputField(
                  key: const ValueKey('kiosk_setup_pin_field'),
                  label: 'Master 4-Digit PIN',
                  hintText: '1234',
                  controller: _masterPinCtrl,
                  prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: DossierButton(
              text: 'Complete Setup & Unlock Kiosk',
              icon: Icons.verified_user_rounded,
              isLoading: auth.isLoading,
              onPressed: _handleKioskRegistration,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Desk Operator Shift PIN Login Card (Software Activated)
  // ─────────────────────────────────────────────────────────────
  Widget _buildOperatorShiftCard(AuthState auth, bool isDark) {
    final operators = auth.registeredOperators.isNotEmpty
        ? auth.registeredOperators
        : (auth.adminOperator != null ? [auth.adminOperator!] : <KioskOperator>[]);

    final selectedOp = operators.firstWhere(
      (o) => o.id == _selectedOperatorId,
      orElse: () => operators.isNotEmpty
          ? operators.first
          : KioskOperator(
              id: 'op-0',
              fullName: 'Operator',
              phone: '',
              role: OperatorRole.operator,
              passwordHash: '',
              pin: '1234',
              kioskName: 'Dossier Kiosk',
              createdAt: DateTime.now(),
            ),
    );

    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operator Shift Sign-In',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      selectedOp.kioskName,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _promptAdminAuthorizationThenAddOperator,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Operator', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Operator Avatar List
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: operators.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final op = operators[i];
                final isSelected = op.id == selectedOp.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOperatorId = op.id;
                      _enteredPin = '';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected ? const Color(0xFF6366F1) : Colors.grey[700],
                          child: Text(
                            op.fullName.isNotEmpty ? op.fullName.substring(0, 1).toUpperCase() : 'O',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              op.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              op.role.label,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 4-Digit PIN Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Touch PIN Keypad
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              children: [
                _buildPinRow(['1', '2', '3'], isDark),
                const SizedBox(height: 10),
                _buildPinRow(['4', '5', '6'], isDark),
                const SizedBox(height: 10),
                _buildPinRow(['7', '8', '9'], isDark),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 68, height: 50),
                    _buildPinButton('0', isDark),
                    SizedBox(
                      width: 68,
                      height: 50,
                      child: InkWell(
                        onTap: _handlePinBackspace,
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: Icon(
                            Icons.backspace_outlined,
                            size: 20,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildPinButton(d, isDark)).toList(),
    );
  }

  Widget _buildPinButton(String digit, bool isDark) {
    return InkWell(
      onTap: () => _handlePinDigit(digit),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 68,
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: GoogleFonts.spaceMono(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
