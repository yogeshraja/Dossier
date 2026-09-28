import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/main.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';

enum ActivationMode { register, signIn }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Activation Mode Controllers
  ActivationMode _activationMode = ActivationMode.register;
  final _adminNameCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _adminPinCtrl = TextEditingController();
  final _kioskNameCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _merchantUpiCtrl = TextEditingController();
  final bool _obscurePassword = true;

  // Operator Shift PIN State
  String _enteredPin = '';
  String? _selectedOperatorId;

  // New Operator Dialog Controllers
  final _newOpNameCtrl = TextEditingController();
  final _newOpPinCtrl = TextEditingController();
  final _newOpPhoneCtrl = TextEditingController();
  final _newOpEmailCtrl = TextEditingController();
  OperatorRole _newOpRole = OperatorRole.operator;

  @override
  void initState() {
    super.initState();
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
    _adminNameCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _adminPinCtrl.dispose();
    _kioskNameCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _merchantUpiCtrl.dispose();
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

  Future<void> _handleActivation() async {
    final isNew = _activationMode == ActivationMode.register;
    final success = await ref.read(authProvider.notifier).activateSoftware(
          adminName: _adminNameCtrl.text,
          phone: _adminPhoneCtrl.text,
          email: _adminEmailCtrl.text.isNotEmpty ? _adminEmailCtrl.text : null,
          password: _adminPasswordCtrl.text,
          pin: _adminPinCtrl.text,
          kioskName: _kioskNameCtrl.text.isNotEmpty ? _kioskNameCtrl.text : 'Main Kiosk Center',
          kioskAddress: _kioskAddressCtrl.text.isNotEmpty ? _kioskAddressCtrl.text : null,
          merchantUpiVpa: _merchantUpiCtrl.text.isNotEmpty ? _merchantUpiCtrl.text : null,
          isNewRegistration: isNew,
        );

    if (success && mounted) {
      _onSuccessfulLogin();
    }
  }

  Future<void> _handlePinDigit(String digit) async {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        final auth = ref.read(authProvider);
        final opId = _selectedOperatorId ?? (auth.registeredOperators.isNotEmpty ? auth.registeredOperators.first.id : 'op-default');
        
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

  void _showAddOperatorDialog() {
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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.3,
            colors: isDark
                ? [
                    const Color(0xFF1E1B4B),
                    const Color(0xFF0F172A),
                    const Color(0xFF090D16),
                  ]
                : [
                    const Color(0xFFEEF2FF),
                    const Color(0xFFF1F5F9),
                    const Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: auth.isSoftwareActivated
                  ? _buildOperatorShiftLogin(context, auth, isDark)
                  : _buildSoftwareActivation(context, auth, isDark),
            ),
          ),
        ),
      ),
    );
  }

  /// Tier 1: Software Activation & Master Admin Setup
  Widget _buildSoftwareActivation(BuildContext context, AuthState auth, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: DossierCard(
        variant: DossierCardVariant.glass,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Connection Status Pill
            _buildServerPill(auth, isDark),
            const SizedBox(height: 16),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Software Activation',
                        style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Admin sign-in to activate kiosk on Cloudflare server',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode Selector (New Kiosk Registration vs Existing Admin Sign-In)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activationMode = ActivationMode.register),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activationMode == ActivationMode.register ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Register New Kiosk',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activationMode == ActivationMode.register ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activationMode = ActivationMode.signIn),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activationMode == ActivationMode.signIn ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sign In Existing Admin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activationMode == ActivationMode.signIn ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form Fields
            if (_activationMode == ActivationMode.register) ...[
              DossierInputField(
                label: 'Kiosk Center Name',
                hintText: 'e.g. Sri Balaji CSC Center',
                controller: _kioskNameCtrl,
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DossierInputField(
                      label: 'Admin Full Name',
                      hintText: 'e.g. Rajesh Sharma',
                      controller: _adminNameCtrl,
                      prefixIcon: const Icon(Icons.person_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DossierInputField(
                      label: 'Mobile Number',
                      hintText: '9876543210',
                      controller: _adminPhoneCtrl,
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DossierInputField(
                label: 'Email (Optional)',
                hintText: 'admin@csc.in',
                controller: _adminEmailCtrl,
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DossierInputField(
                      label: 'Password',
                      hintText: '••••••••',
                      controller: _adminPasswordCtrl,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      obscureText: _obscurePassword,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DossierInputField(
                      label: '4-Digit PIN',
                      hintText: '1234',
                      controller: _adminPinCtrl,
                      prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ] else ...[
              DossierInputField(
                label: 'Admin Mobile / Email',
                hintText: '9876543210 or admin@csc.in',
                controller: _adminPhoneCtrl,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DossierInputField(
                      label: 'Password',
                      hintText: '••••••••',
                      controller: _adminPasswordCtrl,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      obscureText: _obscurePassword,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DossierInputField(
                      label: '4-Digit PIN',
                      hintText: '1234',
                      controller: _adminPinCtrl,
                      prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],

            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(auth.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            DossierButton(
              text: auth.isLoading ? 'Activating with Server...' : (_activationMode == ActivationMode.register ? 'Register & Activate Kiosk' : 'Sign In & Activate'),
              icon: Icons.check_circle_rounded,
              isLoading: auth.isLoading,
              onPressed: auth.isLoading ? null : _handleActivation,
            ),
          ],
        ),
      ),
    );
  }

  /// Tier 2: Operator Shift Login (Select Operator Avatar + 4-Digit PIN)
  Widget _buildOperatorShiftLogin(BuildContext context, AuthState auth, bool isDark) {
    final operators = auth.registeredOperators;
    final selectedOp = operators.firstWhere(
      (o) => o.id == _selectedOperatorId,
      orElse: () => operators.isNotEmpty ? operators.first : (auth.adminOperator ?? KioskOperator(
        id: 'adm',
        fullName: 'Admin',
        phone: '',
        passwordHash: '',
        pin: '1234',
        kioskName: 'Kiosk',
        createdAt: DateTime.now(),
      )),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DossierCard(
        variant: DossierCardVariant.glass,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activated Center Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          auth.adminOperator?.kioskName ?? 'Dossier Kiosk',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const DossierBadge(label: 'Software Active', variant: DossierBadgeVariant.success),
              ],
            ),
            const SizedBox(height: 20),

            // Operator Selection Bar / Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Select Desk Operator',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddOperatorDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Operator', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                        color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.2) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: op.role.color,
                            child: Text(op.initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(op.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(op.role.label, style: TextStyle(fontSize: 10, color: op.role.color)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Enter 4-Digit PIN for Selected Operator
            Text(
              'Enter 4-Digit PIN for ${selectedOp.fullName}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // PIN Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF6366F1) : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Touch PIN Numpad
            _buildNumpad(isDark),

            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(auth.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 16),
            // Reset / Deactivate Option
            TextButton(
              onPressed: () {
                ref.read(authProvider.notifier).resetKioskActivation();
              },
              child: const Text('Deactivate Software / Switch Center', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad(bool isDark) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: () {
                    if (key == 'C') {
                      setState(() => _enteredPin = '');
                    } else if (key == '⌫') {
                      _handlePinBackspace();
                    } else {
                      _handlePinDigit(key);
                    }
                  },
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    width: 64,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      key,
                      style: GoogleFonts.spaceMono(
                        fontSize: key == '⌫' || key == 'C' ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServerPill(AuthState auth, bool isDark) {
    final connected = auth.isServerConnected && !auth.isOfflineMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (connected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (connected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              connected ? 'Cloudflare Edge API Online (${auth.serverUrl})' : 'Offline Mode (Local Cryptographic Cache Active)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: connected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
