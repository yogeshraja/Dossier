import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/main.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

enum AuthMode { signIn, signUp }
enum SignInMethod { password, pin }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  AuthMode _authMode = AuthMode.signIn;
  SignInMethod _signInMethod = SignInMethod.password;

  // Sign-In Form Controllers
  final _signInIdentifierCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();
  bool _obscureSignInPassword = true;

  // PIN Unlock State
  String _enteredPin = '';
  String? _selectedOperatorId;

  // Sign-Up Form Controllers
  final _signUpKioskNameCtrl = TextEditingController();
  final _signUpOperatorNameCtrl = TextEditingController();
  final _signUpPhoneCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();
  final _signUpPinCtrl = TextEditingController();
  final _signUpUpiCtrl = TextEditingController();
  final _signUpAddressCtrl = TextEditingController();
  OperatorRole _signUpRole = OperatorRole.admin;
  bool _obscureSignUpPassword = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Default to sign-up if no operator exists yet, or select the first operator for PIN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.registeredOperators.isEmpty) {
        setState(() {
          _authMode = AuthMode.signUp;
        });
      } else {
        setState(() {
          _selectedOperatorId = auth.registeredOperators.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _signInIdentifierCtrl.dispose();
    _signInPasswordCtrl.dispose();
    _signUpKioskNameCtrl.dispose();
    _signUpOperatorNameCtrl.dispose();
    _signUpPhoneCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signUpPinCtrl.dispose();
    _signUpUpiCtrl.dispose();
    _signUpAddressCtrl.dispose();
    super.dispose();
  }

  void _onSuccessfulAuth() {
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

  Future<void> _handlePasswordSignIn() async {
    final success = await ref.read(authProvider.notifier).signInWithCredentials(
          identifier: _signInIdentifierCtrl.text,
          password: _signInPasswordCtrl.text,
        );
    if (success && mounted) {
      _onSuccessfulAuth();
    }
  }

  Future<void> _handlePinDigit(String digit) async {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        final success = await ref.read(authProvider.notifier).signInWithPin(
              pin: _enteredPin,
              operatorId: _selectedOperatorId,
            );
        if (success && mounted) {
          _onSuccessfulAuth();
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

  Future<void> _handleSignUp() async {
    final success = await ref.read(authProvider.notifier).signUp(
          kioskName: _signUpKioskNameCtrl.text,
          operatorName: _signUpOperatorNameCtrl.text,
          phone: _signUpPhoneCtrl.text,
          email: _signUpEmailCtrl.text,
          password: _signUpPasswordCtrl.text,
          pin: _signUpPinCtrl.text,
          role: _signUpRole,
          merchantUpiVpa: _signUpUpiCtrl.text,
          kioskAddress: _signUpAddressCtrl.text,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kiosk & Master Operator registered successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _onSuccessfulAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final settings = ref.watch(kioskSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.4,
            colors: isDark
                ? [
                    const Color(0xFF1E1B4B), // Deep indigo
                    const Color(0xFF0F172A), // Slate 900
                    const Color(0xFF070B14),
                  ]
                : [
                    const Color(0xFFEEF2FF), // Indigo 50
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Logo & Theme Switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DOSSIER',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Offline-First Kiosk Vault',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Responsive Offline Badge
                    MediaQuery.of(context).size.width >= 400
                        ? const DossierBadge(
                            label: '100% Offline Local Vault',
                            variant: DossierBadgeVariant.success,
                            icon: Icons.offline_bolt_rounded,
                          )
                        : const DossierBadge(
                            label: 'Offline',
                            variant: DossierBadgeVariant.success,
                            icon: Icons.offline_bolt_rounded,
                          ),
                    const SizedBox(width: 4),
                    // Theme Toggle
                    IconButton(
                      icon: Icon(
                        settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                      ),
                      tooltip: 'Toggle Theme',
                      onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
                    ),
                  ],
                ),
              ),

              // Main Responsive Content Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth >= 880;

                    if (isWideScreen) {
                      // Two-Column Layout (Hero Showcase + Auth Card)
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1060),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left Hero Panel
                                Expanded(
                                  flex: 5,
                                  child: _buildHeroShowcasePanel(isDark),
                                ),
                                const SizedBox(width: 32),
                                // Right Auth Card
                                Expanded(
                                  flex: 6,
                                  child: _buildInteractiveAuthCard(isDark, authState),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Single Column Layout for Mobile & Compact Tablets
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: _buildInteractiveAuthCard(isDark, authState),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left Hero Showcase Panel (Desktop / Tablet Viewports)
  Widget _buildHeroShowcasePanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B).withValues(alpha: 0.8), const Color(0xFF0F172A).withValues(alpha: 0.9)]
              : [Colors.white.withValues(alpha: 0.9), const Color(0xFFEEF2FF).withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFF818CF8)),
                    SizedBox(width: 6),
                    Text(
                      'CSC & KIOSK STATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF818CF8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'High-Density Workstation for Cyber Cafes & Service Desks',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Engineered for rapid customer intake, instant ID photo prep, dynamic UPI checkout, and resilient offline local storage.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Feature Grid
          _buildFeatureBullet(
            icon: Icons.storage_rounded,
            title: 'Drift SQLite Offline Vault',
            desc: 'Zero downtime during broadband outages. Data stays securely on-device.',
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildFeatureBullet(
            icon: Icons.camera_enhance_rounded,
            title: 'Pure-Dart Media Studio',
            desc: 'Isolate-driven auto-cropping, ID card stitching, and 6/8/12 passport tiling.',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildFeatureBullet(
            icon: Icons.qr_code_2_rounded,
            title: 'POS Register & Dynamic UPI QR',
            desc: 'Instantly generate UPI payment QR codes and track cash drawers.',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildFeatureBullet(
            icon: Icons.lock_person_rounded,
            title: 'Multi-Operator Shift PIN',
            desc: 'Quick 4-digit terminal switching for operators and counter staff.',
            color: const Color(0xFFEC4899),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Main Interactive Auth Card (Switch between Sign In & Sign Up)
  Widget _buildInteractiveAuthCard(bool isDark, AuthState authState) {
    return DossierCard(
      variant: DossierCardVariant.elevated,
      borderRadius: 20,
      elevation: 6,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ambient Server Endpoint Status Pill
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (authState.isServerConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (authState.isServerConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  authState.isServerConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                  size: 13,
                  color: authState.isServerConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    authState.isServerConnected
                        ? 'Server: api.dossier.app'
                        : 'Offline Mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: authState.isServerConnected
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                          : const Color(0xFFF59E0B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Auth Mode Segmented Control (Sign In vs Sign Up)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _authMode = AuthMode.signIn;
                      });
                      ref.read(authProvider.notifier).clearError();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _authMode == AuthMode.signIn
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _authMode == AuthMode.signIn
                            ? [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Operator Sign-In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _authMode == AuthMode.signIn
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _authMode = AuthMode.signUp;
                      });
                      ref.read(authProvider.notifier).clearError();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _authMode == AuthMode.signUp
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _authMode == AuthMode.signUp
                            ? [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'New Kiosk Setup',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _authMode == AuthMode.signUp
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Error banner if any
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ref.read(authProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Animated Form Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _authMode == AuthMode.signIn
                ? _buildSignInView(isDark, authState)
                : _buildSignUpView(isDark, authState),
          ),
        ],
      ),
    );
  }

  /// Sign In View with sub-tabs for Password vs Quick 4-Digit PIN
  Widget _buildSignInView(bool isDark, AuthState authState) {
    return Column(
      key: const ValueKey('sign_in_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method Selector (Password vs PIN)
        Row(
          children: [
            Expanded(
              child: Text(
                _signInMethod == SignInMethod.password ? 'Enter Credentials' : 'Quick PIN Unlock',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Switch to Password Sign-In',
              icon: Icon(
                Icons.password_rounded,
                size: 20,
                color: _signInMethod == SignInMethod.password ? const Color(0xFF6366F1) : (isDark ? Colors.grey : Colors.blueGrey),
              ),
              onPressed: () => setState(() {
                _signInMethod = SignInMethod.password;
                _enteredPin = '';
              }),
            ),
            IconButton(
              tooltip: 'Switch to Quick 4-Digit PIN Pad',
              icon: Icon(
                Icons.dialpad_rounded,
                size: 20,
                color: _signInMethod == SignInMethod.pin ? const Color(0xFF6366F1) : (isDark ? Colors.grey : Colors.blueGrey),
              ),
              onPressed: () => setState(() {
                _signInMethod = SignInMethod.pin;
                _enteredPin = '';
              }),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_signInMethod == SignInMethod.password) ...[
          // Form: Identifier
          DossierInputField(
            controller: _signInIdentifierCtrl,
            label: 'Mobile Number or Email',
            hintText: 'e.g. 9876543210 or admin@dossier.local',
            prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 14),

          // Form: Password
          DossierInputField(
            controller: _signInPasswordCtrl,
            label: 'Operator Password',
            hintText: 'Enter password',
            obscureText: _obscureSignInPassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignInPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
            ),
            onFieldSubmitted: (_) => _handlePasswordSignIn(),
          ),

          const SizedBox(height: 12),

          // Remember Me & Demo login shortcut
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: authState.rememberMe,
                  onChanged: (val) => ref.read(authProvider.notifier).toggleRememberMe(val ?? true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Remember kiosk session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _signInMethod = SignInMethod.pin;
                }),
                child: const Text('Use PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Submit Button
          DossierButton(
            text: 'Sign In to Kiosk',
            icon: Icons.login_rounded,
            isFullWidth: true,
            size: DossierButtonSize.lg,
            isLoading: authState.isLoading,
            onPressed: _handlePasswordSignIn,
          ),
        ] else ...[
          // Quick PIN Unlock Mode
          _buildPinKeypadView(isDark, authState),
        ],
      ],
    );
  }

  /// 4-Digit PIN Keypad with Operator Selector
  Widget _buildPinKeypadView(bool isDark, AuthState authState) {
    return Column(
      children: [
        // Operator Chips
        if (authState.registeredOperators.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: authState.registeredOperators.map((op) {
                final isSelected = _selectedOperatorId == op.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: op.role.color,
                      child: Text(
                        op.initials,
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    label: Text(op.fullName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedOperatorId = op.id;
                          _enteredPin = '';
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // PIN Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? const Color(0xFF6366F1) : Colors.transparent,
                border: Border.all(
                  color: isFilled
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // 3x4 Numeric Keypad
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            children: [
              _buildKeypadRow(['1', '2', '3'], isDark),
              const SizedBox(height: 10),
              _buildKeypadRow(['4', '5', '6'], isDark),
              const SizedBox(height: 10),
              _buildKeypadRow(['7', '8', '9'], isDark),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clear / Reset
                  _buildKeypadButton(
                    child: const Icon(Icons.restart_alt_rounded, size: 20),
                    onTap: () => setState(() => _enteredPin = ''),
                    isDark: isDark,
                  ),
                  _buildKeypadButton(
                    child: const Text('0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () => _handlePinDigit('0'),
                    isDark: isDark,
                  ),
                  // Backspace
                  _buildKeypadButton(
                    child: const Icon(Icons.backspace_outlined, size: 18),
                    onTap: _handlePinBackspace,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) {
        return _buildKeypadButton(
          child: Text(d, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          onTap: () => _handlePinDigit(d),
          isDark: isDark,
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  /// Sign Up / New Kiosk Setup View
  Widget _buildSignUpView(bool isDark, AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('sign_up_view'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register Kiosk & Master Operator',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your primary local vault workstation credentials.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Kiosk Name
          DossierInputField(
            controller: _signUpKioskNameCtrl,
            label: 'CSC / Kiosk Business Name',
            hintText: 'e.g. Sri Balaji Digital Seva',
            prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
          ),
          const SizedBox(height: 12),

          // Operator Name & Phone in 2-column if space permits
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 380) {
                return Row(
                  children: [
                    Expanded(
                      child: DossierInputField(
                        controller: _signUpOperatorNameCtrl,
                        label: 'Master Operator Name',
                        hintText: 'e.g. Vikram Singh',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DossierInputField(
                        controller: _signUpPhoneCtrl,
                        label: 'Mobile Number',
                        hintText: 'e.g. 9845012345',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    DossierInputField(
                      controller: _signUpOperatorNameCtrl,
                      label: 'Master Operator Name',
                      hintText: 'e.g. Vikram Singh',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      controller: _signUpPhoneCtrl,
                      label: 'Mobile Number',
                      hintText: 'e.g. 9845012345',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // Email & UPI ID
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 380) {
                return Row(
                  children: [
                    Expanded(
                      child: DossierInputField(
                        controller: _signUpEmailCtrl,
                        label: 'Email (Optional)',
                        hintText: 'operator@kiosk.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DossierInputField(
                        controller: _signUpUpiCtrl,
                        label: 'Merchant UPI VPA',
                        hintText: 'kiosk@oksbi',
                        prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    DossierInputField(
                      controller: _signUpEmailCtrl,
                      label: 'Email (Optional)',
                      hintText: 'operator@kiosk.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      controller: _signUpUpiCtrl,
                      label: 'Merchant UPI VPA',
                      hintText: 'kiosk@oksbi',
                      prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // Password & 4-Digit PIN
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DossierInputField(
                  controller: _signUpPasswordCtrl,
                  label: 'Password',
                  hintText: 'Create password',
                  obscureText: _obscureSignUpPassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSignUpPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DossierInputField(
                  controller: _signUpPinCtrl,
                  label: '4-Digit PIN',
                  hintText: 'e.g. 4321',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  prefixIcon: const Icon(Icons.dialpad_rounded, size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Role Selector
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Role: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              ...OperatorRole.values.map((role) {
                final isSelected = _signUpRole == role;
                return ChoiceChip(
                  avatar: Icon(role.icon, size: 14, color: isSelected ? Colors.white : role.color),
                  label: Text(role.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _signUpRole = role);
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 18),

          // Submit Button
          DossierButton(
            text: 'Create Kiosk & Get Started',
            icon: Icons.check_circle_rounded,
            isFullWidth: true,
            size: DossierButtonSize.lg,
            isLoading: authState.isLoading,
            onPressed: _handleSignUp,
          ),
        ],
      ),
    );
  }
}
