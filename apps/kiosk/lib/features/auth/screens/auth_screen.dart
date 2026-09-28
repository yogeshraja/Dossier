import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/core/models/country_code.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy_factory.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/main.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_country_picker.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Step 1: User Login / Sign-up State
  AuthMode _authMode = AuthMode.signIn;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  CountryCode _signUpCountry = CountryCode.defaultCountry;
  CountryCode _signInCountry = CountryCode.defaultCountry;
  CountryCode _otpCountry = CountryCode.defaultCountry;

  // Sign-In with OTP State
  bool _isSignInOtpMode = false;
  bool _signInOtpSent = false;
  final _signInOtpCtrl = TextEditingController();
  int _signInOtpTimerSeconds = 0;
  Timer? _signInOtpCountdownTimer;
  String? _signInOtpFeedbackMessage;

  // Sign-Up Mobile OTP State (Mobile-First Verification Flow)
  bool _signUpOtpSent = false;
  bool _signUpOtpVerified = false;
  final _signUpOtpCtrl = TextEditingController();
  int _signUpTimerSeconds = 0;
  Timer? _signUpCountdownTimer;
  String? _signUpFeedbackMessage;

  // Step 1.5: Twilio Mobile OTP Verification State (For Existing / SSO Users)
  final _otpMobileCtrl = TextEditingController();
  final _otpCodeCtrl = TextEditingController();
  bool _isOtpSent = false;
  int _otpTimerSeconds = 0;
  Timer? _otpCountdownTimer;
  String? _otpFeedbackMessage;

  // Step 2: Kiosk Product Registration & FTUE State
  int _ftueStep = 0;
  final _kioskNameCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _kioskContactCtrl = TextEditingController();
  final _merchantUpiCtrl = TextEditingController();
  final _masterPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  int _receiptWidthMm = 58;
  bool _autoCashDrawer = true;

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
    _confirmPinCtrl.text = '1234';

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
    _signUpCountdownTimer?.cancel();
    _signInOtpCountdownTimer?.cancel();
    _otpCountdownTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _signInOtpCtrl.dispose();
    _signUpOtpCtrl.dispose();
    _otpMobileCtrl.dispose();
    _otpCodeCtrl.dispose();
    _kioskNameCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _kioskContactCtrl.dispose();
    _merchantUpiCtrl.dispose();
    _masterPinCtrl.dispose();
    _confirmPinCtrl.dispose();
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

  bool _isEmailIdentifier(String input) {
    return input.trim().contains('@');
  }

  void _startSignInOtpTimer() {
    _signInOtpCountdownTimer?.cancel();
    setState(() {
      _signInOtpTimerSeconds = 30;
    });
    _signInOtpCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_signInOtpTimerSeconds > 0) {
        setState(() {
          _signInOtpTimerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Handle Send OTP for Sign-In Flow
  Future<void> _handleSignInSendOtp() async {
    final rawInput = _identifierCtrl.text.trim();
    final cleanDigits = rawInput.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.length < _signInCountry.minDigits || cleanDigits.length > _signInCountry.maxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid ${_signInCountry.minDigits}-${_signInCountry.maxDigits} digit mobile number for OTP sign-in.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final formatted = _signInCountry.formatFullNumber(cleanDigits);
    final success = await ref.read(authProvider.notifier).sendOtp(formatted, purpose: 'signin');
    if (success && mounted) {
      setState(() {
        _signInOtpSent = true;
        _signInOtpFeedbackMessage = 'Verification code sent to $formatted';
      });
      _startSignInOtpTimer();
    }
  }

  // Handle Verify OTP for Sign-In Flow
  Future<void> _handleSignInVerifyOtp() async {
    final cleanDigits = _identifierCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final formatted = _signInCountry.formatFullNumber(cleanDigits);
    final otp = _signInOtpCtrl.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).signInWithOtp(
          mobile: formatted,
          otp: otp,
        );

    if (success && mounted) {
      _signInOtpCountdownTimer?.cancel();
      final auth = ref.read(authProvider);
      if (auth.isSoftwareActivated) {
        _onSuccessfulLogin();
      }
    }
  }

  void _startSignUpOtpTimer() {
    _signUpCountdownTimer?.cancel();
    setState(() {
      _signUpTimerSeconds = 30;
    });
    _signUpCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_signUpTimerSeconds > 0) {
        setState(() {
          _signUpTimerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Handle Send OTP for Sign-Up Flow
  Future<void> _handleSignUpSendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    final cleanDigits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.length < _signUpCountry.minDigits || cleanDigits.length > _signUpCountry.maxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid ${_signUpCountry.minDigits}-${_signUpCountry.maxDigits} digit mobile number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final formatted = _signUpCountry.formatFullNumber(cleanDigits);
    final success = await ref.read(authProvider.notifier).sendOtp(formatted, purpose: 'signup');
    if (success && mounted) {
      setState(() {
        _signUpOtpSent = true;
        _signUpFeedbackMessage = 'Verification code sent to $formatted';
      });
      _startSignUpOtpTimer();
    }
  }

  // Handle Verify OTP for Sign-Up Flow
  Future<void> _handleSignUpVerifyOtp() async {
    final cleanDigits = _mobileCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final formatted = _signUpCountry.formatFullNumber(cleanDigits);
    final otp = _signUpOtpCtrl.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).verifyOtp(
          mobile: formatted,
          otp: otp,
        );

    if (success && mounted) {
      _signUpCountdownTimer?.cancel();
      setState(() {
        _signUpOtpVerified = true;
        _signUpFeedbackMessage = null;
      });
    }
  }

  void _startOtpTimer() {
    _otpCountdownTimer?.cancel();
    setState(() {
      _otpTimerSeconds = 30;
    });
    _otpCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpTimerSeconds > 0) {
        setState(() {
          _otpTimerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Handle Send OTP via SMS
  Future<void> _handleSendOtp() async {
    final mobile = _otpMobileCtrl.text.trim();
    final cleanDigits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.length < _otpCountry.minDigits || cleanDigits.length > _otpCountry.maxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid ${_otpCountry.minDigits}-${_otpCountry.maxDigits} digit mobile number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final formatted = _otpCountry.formatFullNumber(cleanDigits);
    final success = await ref.read(authProvider.notifier).sendOtp(formatted);
    if (success && mounted) {
      setState(() {
        _isOtpSent = true;
        _otpFeedbackMessage = 'Verification code sent to $formatted';
      });
      _startOtpTimer();
    }
  }

  // Handle Verify OTP Code
  Future<void> _handleVerifyOtp() async {
    final cleanDigits = _otpMobileCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final formatted = _otpCountry.formatFullNumber(cleanDigits);
    final otp = _otpCodeCtrl.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).linkAndVerifyMobile(
          mobile: formatted,
          otp: otp,
        );

    if (success && mounted) {
      _otpCountdownTimer?.cancel();
      final auth = ref.read(authProvider);
      if (auth.isSoftwareActivated) {
        _onSuccessfulLogin();
      }
    }
  }

  // Handle User Login / Sign-up via Strategy
  Future<void> _handleUserAuth() async {
    final isSignUp = _authMode == AuthMode.signUp;
    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Admin';
    final password = _passwordCtrl.text.trim().isNotEmpty ? _passwordCtrl.text.trim() : '1234';

    final strategy = isSignUp
        ? AuthStrategyFactory.createPhoneStrategy(
            phone: _signUpCountry.formatFullNumber(_mobileCtrl.text.trim()),
            password: password,
            name: name,
          )
        : (_isEmailIdentifier(_identifierCtrl.text)
            ? AuthStrategyFactory.createEmailStrategy(
                email: _identifierCtrl.text.trim(),
                password: _passwordCtrl.text.trim(),
                name: _nameCtrl.text.trim(),
              )
            : AuthStrategyFactory.createPhoneStrategy(
                phone: _signInCountry.formatFullNumber(_identifierCtrl.text.trim()),
                password: _passwordCtrl.text.trim(),
                name: _nameCtrl.text.trim(),
              ));

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

  // Handle Kiosk Registration & Software Activation (FTUE Completion)
  Future<void> _handleKioskRegistration() async {
    final pin = _masterPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (confirmPin.isNotEmpty && pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Master PINs do not match. Please verify your PIN.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).registerKioskAndActivate(
          kioskName: _kioskNameCtrl.text,
          kioskAddress: _kioskAddressCtrl.text.isNotEmpty ? _kioskAddressCtrl.text : null,
          merchantUpiVpa: _merchantUpiCtrl.text.isNotEmpty ? _merchantUpiCtrl.text : null,
          pin: pin.isNotEmpty ? pin : '1234',
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
          'Offline-ready workstation, instant operator PIN shifts, high-speed receipt printing, and automatic cloud backup.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildPillBenefit(Icons.security_rounded, 'Secure Account & Device Protection', isDark),
        const SizedBox(height: 12),
        _buildPillBenefit(Icons.offline_pin_rounded, '100% Offline Operation & Local Storage', isDark),
        const SizedBox(height: 12),
        _buildPillBenefit(Icons.cloud_sync_rounded, 'Automatic Cloud Synchronization', isDark),
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

    // Flow 2: User is Logged In, but Mobile is NOT Verified -> Twilio SMS OTP Verification
    if (auth.isUserLoggedIn && !(auth.user?.isMobileVerified ?? false) && !auth.isSoftwareActivated) {
      return _buildMobileVerificationCard(auth, isDark);
    }

    // Flow 3: User is Logged In & Mobile is Verified, but Kiosk is NOT Registered/Activated -> Kiosk Setup Screen (FTUE)
    if (auth.isUserLoggedIn && !auth.isSoftwareActivated) {
      return _buildKioskSetupCard(auth, isDark);
    }

    // Flow 4: Software is Activated -> Operator Shift PIN Login
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
                label: auth.isServerConnected ? 'ONLINE' : 'OFFLINE MODE',
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
                  child: Tooltip(
                    message: 'Sign into existing kiosk workstation account',
                    child: InkWell(
                      onTap: () {
                        ref.read(authProvider.notifier).clearError();
                        setState(() {
                          _authMode = AuthMode.signIn;
                          _signUpOtpSent = false;
                          _signUpOtpVerified = false;
                        });
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
                ),
                Expanded(
                  child: Tooltip(
                    message: 'Register a new center account and activate device',
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error banner
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (isSignUp &&
                      (auth.errorMessage!.contains('already exists') || auth.errorMessage!.contains('sign in'))) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: 'Switch to Sign In mode with prefilled phone number',
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            final mob = _mobileCtrl.text.trim();
                            ref.read(authProvider.notifier).clearError();
                            setState(() {
                              _authMode = AuthMode.signIn;
                              _isSignInOtpMode = false;
                              _identifierCtrl.text = mob;
                            });
                          },
                          icon: const Icon(Icons.login_rounded, size: 14, color: Color(0xFF6366F1)),
                          label: const Text(
                            'Switch to Sign In →',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Sign-Up Feedback Banner
          if (isSignUp && _signUpFeedbackMessage != null && auth.errorMessage == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _signUpFeedbackMessage!,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Sign-In OTP Feedback Banner
          if (!isSignUp && _isSignInOtpMode && _signInOtpFeedbackMessage != null && auth.errorMessage == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _signInOtpFeedbackMessage!,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ─── Flow 1A: SIGN-UP FLOW (Mobile OTP First) ───
          if (isSignUp) ...[
            if (!_signUpOtpVerified) ...[
              // Step 1: Just Mobile Number (No Password, No Name)
              if (!_signUpOtpSent) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: DossierCountryPicker(
                        key: const ValueKey('signup_country_picker'),
                        selectedCountry: _signUpCountry,
                        onCountryChanged: (c) {
                          setState(() => _signUpCountry = c);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DossierInputField(
                        key: const ValueKey('auth_mobile_field'),
                        label: 'Mobile Number',
                        hintText: _signUpCountry.example,
                        controller: _mobileCtrl,
                        prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DossierButton(
                    key: const ValueKey('signup_send_otp_button'),
                    text: 'Send Verification OTP',
                    icon: Icons.sms_rounded,
                    isLoading: auth.isLoading,
                    onPressed: _handleSignUpSendOtp,
                  ),
                ),
              ] else ...[
                // Step 2: 6-Digit OTP Verification
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(_signUpCountry.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            _signUpCountry.formatFullNumber(_mobileCtrl.text),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _signUpOtpSent = false;
                            _signUpOtpCtrl.clear();
                            _signUpCountdownTimer?.cancel();
                          });
                        },
                        child: const Text(
                          'Change',
                          style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DossierInputField(
                  key: const ValueKey('signup_otp_field'),
                  label: '6-Digit Verification Code',
                  hintText: '••••••',
                  controller: _signUpOtpCtrl,
                  prefixIcon: const Icon(Icons.security_rounded, size: 18),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A 6-digit verification code has been sent via SMS.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DossierButton(
                    key: const ValueKey('signup_verify_otp_button'),
                    text: 'Verify Code & Proceed',
                    tooltip: 'Verify 6-digit code and proceed to account details',
                    icon: Icons.verified_user_rounded,
                    isLoading: auth.isLoading,
                    onPressed: _handleSignUpVerifyOtp,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Tooltip(
                    message: _signUpTimerSeconds > 0 ? 'Wait for countdown before requesting a new code' : 'Request a new SMS verification code',
                    child: TextButton(
                      onPressed: _signUpTimerSeconds > 0 || auth.isLoading ? null : _handleSignUpSendOtp,
                      child: Text(
                        _signUpTimerSeconds > 0 ? 'Resend code in ${_signUpTimerSeconds}s' : 'Resend OTP SMS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _signUpTimerSeconds > 0 ? Colors.grey : const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Step 3: Verified Mobile -> Open Other Fields (Name, Email, Password)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified Mobile: ${_signUpCountry.formatFullNumber(_mobileCtrl.text)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DossierInputField(
                key: const ValueKey('auth_signup_name_field'),
                label: 'Full Name',
                hintText: 'e.g. Ramesh Kumar',
                controller: _nameCtrl,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              ),
              const SizedBox(height: 12),
              DossierInputField(
                key: const ValueKey('auth_email_field'),
                label: 'Email Address (Optional)',
                hintText: 'admin@csc.in',
                controller: _emailCtrl,
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DossierInputField(
                key: const ValueKey('auth_password_field'),
                label: 'Create Master Password',
                hintText: '••••••••',
                controller: _passwordCtrl,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: DossierButton(
                  key: const ValueKey('auth_complete_signup_button'),
                  text: 'Create Admin Account',
                  icon: Icons.person_add_rounded,
                  isLoading: auth.isLoading,
                  onPressed: _handleUserAuth,
                ),
              ),
            ],
          ] else ...[
            // ─── Flow 1B: SIGN-IN FLOW (Unified Identifier + Password or SMS OTP) ───
            if (_isSignInOtpMode) ...[
              // OTP Sign-In with Country Picker
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: DossierCountryPicker(
                      key: const ValueKey('signin_country_picker'),
                      selectedCountry: _signInCountry,
                      onCountryChanged: (c) {
                        setState(() => _signInCountry = c);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DossierInputField(
                      key: const ValueKey('auth_identifier_field'),
                      label: 'Mobile Number',
                      hintText: _signInCountry.example,
                      controller: _identifierCtrl,
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Password Sign-In with Unified Email / Phone Identifier
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _identifierCtrl,
                builder: (context, val, _) {
                  final isEmail = val.text.contains('@');
                  final isPhone = !isEmail && val.text.trim().isNotEmpty && RegExp(r'^\+?[\d\s\-]+$').hasMatch(val.text.trim());
                  return DossierInputField(
                    key: const ValueKey('auth_identifier_field'),
                    label: isEmail ? 'Email Address' : (isPhone ? 'Mobile Number / E.164 (+)' : 'Email or Mobile Number'),
                    hintText: isEmail ? 'admin@csc.in' : (isPhone ? '+91 9876543210' : 'admin@csc.in or 9876543210'),
                    controller: _identifierCtrl,
                    prefixIcon: Icon(
                      isEmail
                          ? Icons.email_outlined
                          : (isPhone ? Icons.phone_android_rounded : Icons.alternate_email_rounded),
                      size: 18,
                    ),
                    keyboardType: isEmail
                        ? TextInputType.emailAddress
                        : (isPhone ? TextInputType.phone : TextInputType.text),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),

            if (!_isSignInOtpMode) ...[
              // Mode 1: Default Password Sign-In
              DossierInputField(
                key: const ValueKey('auth_password_field'),
                label: 'Password',
                hintText: '••••••••',
                controller: _passwordCtrl,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
              const SizedBox(height: 20),

              // Primary Sign-In CTA Button
              SizedBox(
                width: double.infinity,
                child: DossierButton(
                  key: const ValueKey('auth_signin_button'),
                  text: 'Sign In to Dossier',
                  icon: Icons.login_rounded,
                  isLoading: auth.isLoading,
                  onPressed: _handleUserAuth,
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  key: const ValueKey('switch_to_otp_signin_button'),
                  onPressed: () {
                    ref.read(authProvider.notifier).clearError();
                    setState(() {
                      _isSignInOtpMode = true;
                      _signInOtpSent = false;
                      _signInOtpCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.sms_outlined, size: 16),
                  label: const Text(
                    'Sign in with SMS OTP instead',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ] else ...[
              // Mode 2: SMS OTP Sign-In
              if (!_signInOtpSent) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: DossierButton(
                    key: const ValueKey('signin_send_otp_button'),
                    text: 'Send Sign-In OTP',
                    icon: Icons.sms_rounded,
                    isLoading: auth.isLoading,
                    onPressed: _handleSignInSendOtp,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('switch_to_password_signin_button'),
                    onPressed: () {
                      ref.read(authProvider.notifier).clearError();
                      setState(() {
                        _isSignInOtpMode = false;
                        _signInOtpSent = false;
                      });
                    },
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: const Text(
                      'Sign in with Password instead',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
              ] else ...[
                // OTP code entry for sign-in
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(_signInCountry.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            _signInCountry.formatFullNumber(_identifierCtrl.text),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _signInOtpSent = false;
                            _signInOtpCtrl.clear();
                            _signInOtpCountdownTimer?.cancel();
                          });
                        },
                        child: const Text(
                          'Change',
                          style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DossierInputField(
                  key: const ValueKey('signin_otp_field'),
                  label: '6-Digit Verification Code',
                  hintText: '••••••',
                  controller: _signInOtpCtrl,
                  prefixIcon: const Icon(Icons.security_rounded, size: 18),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A 6-digit verification code has been sent via SMS.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DossierButton(
                    key: const ValueKey('signin_verify_otp_button'),
                    text: 'Verify & Sign In',
                    tooltip: 'Verify code and open kiosk workstation',
                    icon: Icons.verified_user_rounded,
                    isLoading: auth.isLoading,
                    onPressed: _handleSignInVerifyOtp,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tooltip(
                      message: _signInOtpTimerSeconds > 0 ? 'Wait for countdown before requesting a new code' : 'Request a new sign-in code via SMS',
                      child: TextButton(
                        onPressed: _signInOtpTimerSeconds > 0 || auth.isLoading ? null : _handleSignInSendOtp,
                        child: Text(
                          _signInOtpTimerSeconds > 0 ? 'Resend in ${_signInOtpTimerSeconds}s' : 'Resend OTP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _signInOtpTimerSeconds > 0 ? Colors.grey : const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Switch back to signing in with your account password',
                      child: TextButton(
                        onPressed: () {
                          ref.read(authProvider.notifier).clearError();
                          setState(() {
                            _isSignInOtpMode = false;
                            _signInOtpSent = false;
                          });
                        },
                        child: const Text(
                          'Use Password',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
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
          Tooltip(
            message: 'Sign in quickly and securely with your Google Account',
            child: SizedBox(
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
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1.5. Mobile OTP Verification Card (Twilio SMS Gate)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileVerificationCard(AuthState auth, bool isDark) {
    if (_otpMobileCtrl.text.isEmpty && auth.user?.phone != null && auth.user!.phone!.isNotEmpty) {
      final detected = CountryCode.detectFromPhoneString(auth.user!.phone!);
      _otpCountry = detected;
      final clean = auth.user!.phone!.replaceAll(detected.dialCode, '').replaceAll(' ', '');
      _otpMobileCtrl.text = clean;
    }

    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'STEP 1 OF 2 : PHONE VERIFICATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const DossierBadge(
                          label: 'SMS VERIFICATION',
                          variant: DossierBadgeVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verify Your Mobile Number',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                tooltip: 'Sign Out / Switch Account',
                onPressed: () {
                  ref.read(authProvider.notifier).signOut();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To protect your account and verify your identity, please verify your mobile phone number before completing workstation setup.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 20),

          // Error / Success Message
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
          if (_otpFeedbackMessage != null && auth.errorMessage == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _otpFeedbackMessage!,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Phone Number Input with Country Code Picker
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: DossierCountryPicker(
                  key: const ValueKey('otp_country_picker'),
                  selectedCountry: _otpCountry,
                  onCountryChanged: (c) {
                    setState(() => _otpCountry = c);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DossierInputField(
                  key: const ValueKey('otp_mobile_field'),
                  label: 'Mobile Number',
                  hintText: _otpCountry.example,
                  controller: _otpMobileCtrl,
                  enabled: !_isOtpSent,
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_isOtpSent) ...[
            SizedBox(
              width: double.infinity,
              child: DossierButton(
                key: const ValueKey('send_otp_button'),
                text: 'Send Verification OTP',
                tooltip: 'Send 6-digit SMS verification code to this phone number',
                icon: Icons.sms_rounded,
                isLoading: auth.isLoading,
                onPressed: _handleSendOtp,
              ),
            ),
          ] else ...[
            // OTP Code Input Field
            DossierInputField(
              key: const ValueKey('otp_code_field'),
              label: '6-Digit Verification Code',
              hintText: '••••••',
              controller: _otpCodeCtrl,
              prefixIcon: const Icon(Icons.security_rounded, size: 18),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // Customer Verification Hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A 6-digit verification code has been sent via SMS.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Verify Button
            SizedBox(
              width: double.infinity,
              child: DossierButton(
                key: const ValueKey('verify_otp_button'),
                text: 'Verify Mobile & Continue',
                tooltip: 'Verify code and continue to center workstation setup',
                icon: Icons.verified_user_rounded,
                isLoading: auth.isLoading,
                onPressed: _handleVerifyOtp,
              ),
            ),
            const SizedBox(height: 14),

            // Resend & Change Phone Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tooltip(
                  message: 'Enter a different mobile phone number',
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isOtpSent = false;
                        _otpCodeCtrl.clear();
                        _otpFeedbackMessage = null;
                        _otpCountdownTimer?.cancel();
                      });
                    },
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Change Number', style: TextStyle(fontSize: 12)),
                  ),
                ),
                Tooltip(
                  message: _otpTimerSeconds > 0 ? 'Wait for countdown before requesting a new code' : 'Request a new SMS verification code',
                  child: TextButton(
                    onPressed: _otpTimerSeconds > 0 || auth.isLoading ? null : _handleSendOtp,
                    child: Text(
                      _otpTimerSeconds > 0 ? 'Resend in ${_otpTimerSeconds}s' : 'Resend OTP SMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _otpTimerSeconds > 0 ? Colors.grey : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Multi-Step FTUE (First-Time User Experience) Kiosk Setup
  // ─────────────────────────────────────────────────────────────
  Widget _buildKioskSetupCard(AuthState auth, bool isDark) {
    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header & Sign Out
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'FTUE ONBOARDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          'Step ${_ftueStep + 1} of 3',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kiosk Workstation Setup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
            'Authenticated as ${auth.user?.name ?? "Admin"}. Complete this 3-step setup to activate your kiosk vault and desk features.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Visual Stepper Progress Bar
          _buildFtueStepperIndicator(isDark),
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

          // Active Step Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildFtueStepContent(auth, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFtueStepperIndicator(bool isDark) {
    final steps = [
      {'label': '1. Identity', 'icon': Icons.storefront_rounded},
      {'label': '2. POS & UPI', 'icon': Icons.point_of_sale_rounded},
      {'label': '3. Security PIN', 'icon': Icons.shield_rounded},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(steps.length, (stepIdx) {
        final isCurrent = _ftueStep == stepIdx;
        final isPassed = _ftueStep > stepIdx;

        return InkWell(
          onTap: () {
            if (isPassed || stepIdx <= _ftueStep) {
              setState(() => _ftueStep = stepIdx);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF6366F1)
                  : (isPassed
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF6366F1)
                    : (isPassed ? const Color(0xFF10B981) : Colors.transparent),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPassed ? Icons.check_circle_rounded : steps[stepIdx]['icon'] as IconData,
                  size: 14,
                  color: isCurrent
                      ? Colors.white
                      : (isPassed
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.grey[400] : Colors.grey[600])),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[stepIdx]['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? Colors.white
                        : (isPassed
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.grey[300] : Colors.grey[700])),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFtueStepContent(AuthState auth, bool isDark) {
    switch (_ftueStep) {
      case 0:
        return _buildFtueStep0Identity(auth, isDark);
      case 1:
        return _buildFtueStep1PosHardware(auth, isDark);
      case 2:
      default:
        return _buildFtueStep2Security(auth, isDark);
    }
  }

  // ── Step 0: Center Identity & Branding ──
  Widget _buildFtueStep0Identity(AuthState auth, bool isDark) {
    return Column(
      key: const ValueKey('ftue_step_0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Center Name & Physical Address',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'These details appear on printed thermal customer receipts and payment slips.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 16),

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
          label: 'Center Street Address',
          hintText: 'Shop #12, Market Road, Near Bus Stand',
          controller: _kioskAddressCtrl,
          prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
        ),
        const SizedBox(height: 12),

        DossierInputField(
          key: const ValueKey('kiosk_setup_contact_field'),
          label: 'Customer Support / Helpline Phone (Optional)',
          hintText: '+91 98765 43210',
          controller: _kioskContactCtrl,
          prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: DossierButton(
            text: 'Continue to POS Setup →',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              if (_kioskNameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a business / kiosk name.')),
                );
                return;
              }
              setState(() => _ftueStep = 1);
            },
          ),
        ),
      ],
    );
  }

  // ── Step 1: Touch POS & Hardware Configuration ──
  Widget _buildFtueStep1PosHardware(AuthState auth, bool isDark) {
    return Column(
      key: const ValueKey('ftue_step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Touch POS & Payments Setup',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure dynamic UPI QR payments and your connected ESC/POS thermal printer hardware.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        DossierInputField(
          key: const ValueKey('kiosk_setup_upi_field'),
          label: 'Merchant UPI VPA ID (For Instant Customer QR Payments)',
          hintText: 'kiosk@oksbi or 9876543210@paytm',
          controller: _merchantUpiCtrl,
          prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
        ),
        const SizedBox(height: 16),

        // Thermal Receipt Paper Width
        Text(
          'Thermal Receipt Printer Width',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('58mm (Compact - 32 Chars)', style: TextStyle(fontSize: 12)),
              selected: _receiptWidthMm == 58,
              onSelected: (val) {
                if (val) setState(() => _receiptWidthMm = 58);
              },
            ),
            ChoiceChip(
              label: const Text('80mm (Standard - 48 Chars)', style: TextStyle(fontSize: 12)),
              selected: _receiptWidthMm == 80,
              onSelected: (val) {
                if (val) setState(() => _receiptWidthMm = 80);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Auto Cash Drawer Kick
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.point_of_sale_rounded, size: 20, color: const Color(0xFF6366F1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto Cash Drawer Kick', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Send ESC p pulse after cash sales', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Switch(
                value: _autoCashDrawer,
                activeThumbColor: const Color(0xFF6366F1),
                onChanged: (val) => setState(() => _autoCashDrawer = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _ftueStep = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DossierButton(
                text: 'Continue to Security PIN →',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => setState(() => _ftueStep = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: Master Security PIN & Launch ──
  Widget _buildFtueStep2Security(AuthState auth, bool isDark) {
    return Column(
      key: const ValueKey('ftue_step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Master Admin PIN & Launch',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Set a 4-digit Master Admin PIN to protect operator provisioning and tenant settings.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: DossierInputField(
                key: const ValueKey('kiosk_setup_pin_field'),
                label: 'Master 4-Digit PIN',
                hintText: '1234',
                controller: _masterPinCtrl,
                obscureText: true,
                prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DossierInputField(
                key: const ValueKey('kiosk_setup_pin_confirm_field'),
                label: 'Confirm 4-Digit PIN',
                hintText: '1234',
                controller: _confirmPinCtrl,
                obscureText: true,
                prefixIcon: const Icon(Icons.verified_user_outlined, size: 18),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Preview Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    'Configuration Summary',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSummaryRow('Kiosk Center:', _kioskNameCtrl.text, isDark),
              _buildSummaryRow('Merchant UPI:', _merchantUpiCtrl.text, isDark),
              _buildSummaryRow('Printer Paper:', '${_receiptWidthMm}mm ESC/POS', isDark),
              _buildSummaryRow('Admin Account:', auth.user?.name ?? 'Admin', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _ftueStep = 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DossierButton(
                text: 'Complete Setup & Launch 🚀',
                icon: Icons.rocket_launch_rounded,
                isLoading: auth.isLoading,
                onPressed: _handleKioskRegistration,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value.isNotEmpty ? value : 'Default', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
