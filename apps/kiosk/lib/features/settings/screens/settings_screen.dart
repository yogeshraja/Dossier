import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/features/auth/screens/auth_screen.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/features/sync/screens/vault_sync_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const SettingsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Kiosk Profile Controllers
  final _kioskNameCtrl = TextEditingController();
  final _kioskPhoneCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _upiVpaCtrl = TextEditingController();

  // User Profile Controllers
  final _userFullNameCtrl = TextEditingController();
  final _userPhoneCtrl = TextEditingController();
  final _userEmailCtrl = TextEditingController();

  // Change PIN Controllers
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  // New Operator Dialog State
  final _newOpNameCtrl = TextEditingController();
  final _newOpPinCtrl = TextEditingController();
  final _newOpPhoneCtrl = TextEditingController();
  final _newOpEmailCtrl = TextEditingController();
  OperatorRole _newOpRole = OperatorRole.operator;

  // Workplace preference state
  bool _includeOperatorOnReceipt = true;
  bool _autoCutReceipt = true;
  String _receiptPaperWidth = '80mm';
  bool _soundFeedback = true;

  static const _currencyPresets = [
    {'symbol': '₹', 'code': 'INR', 'label': '₹ INR'},
    {'symbol': '\$', 'code': 'USD', 'label': '\$ USD'},
    {'symbol': '€', 'code': 'EUR', 'label': '€ EUR'},
    {'symbol': '£', 'code': 'GBP', 'label': '£ GBP'},
    {'symbol': 'AED', 'code': 'AED', 'label': 'AED'},
    {'symbol': 'SAR', 'code': 'SAR', 'label': 'SAR'},
    {'symbol': '৳', 'code': 'BDT', 'label': '৳ BDT'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 4));

    final settings = ref.read(kioskSettingsProvider);
    _kioskNameCtrl.text = settings.kioskName;
    _kioskPhoneCtrl.text = settings.kioskPhone;
    _kioskAddressCtrl.text = settings.kioskAddress;
    _upiVpaCtrl.text = settings.merchantUpiVpa;

    final auth = ref.read(authProvider);
    final curOp = auth.currentOperator;
    if (curOp != null) {
      _userFullNameCtrl.text = curOp.fullName;
      _userPhoneCtrl.text = curOp.phone;
      _userEmailCtrl.text = curOp.email ?? '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kioskNameCtrl.dispose();
    _kioskPhoneCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _upiVpaCtrl.dispose();
    _userFullNameCtrl.dispose();
    _userPhoneCtrl.dispose();
    _userEmailCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _newOpNameCtrl.dispose();
    _newOpPinCtrl.dispose();
    _newOpPhoneCtrl.dispose();
    _newOpEmailCtrl.dispose();
    super.dispose();
  }

  void _saveKioskProfile() {
    final auth = ref.read(authProvider);
    final isAdmin = auth.currentOperator?.role == OperatorRole.admin || auth.user?.role == 'admin';
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Only Kiosk Admins can modify center identity.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: _kioskNameCtrl.text.trim(),
          address: _kioskAddressCtrl.text.trim(),
          phone: _kioskPhoneCtrl.text.trim(),
          upiVpa: _upiVpaCtrl.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kiosk Profile & Receipt Headers updated!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _saveUserProfile() async {
    final curOp = ref.read(authProvider).currentOperator;
    if (curOp == null) return;

    final success = await ref.read(authProvider.notifier).updateOperatorProfile(
          operatorId: curOp.id,
          fullName: _userFullNameCtrl.text.trim(),
          phone: _userPhoneCtrl.text.trim(),
          email: _userEmailCtrl.text.trim().isNotEmpty ? _userEmailCtrl.text.trim() : null,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operator profile successfully updated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update operator profile.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleChangePin() async {
    final curOp = ref.read(authProvider).currentOperator;
    if (curOp == null) return;

    if (_newPinCtrl.text.trim() != _confirmPinCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PIN and Confirm PIN do not match.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).changeOperatorPin(
          operatorId: curOp.id,
          currentPin: _currentPinCtrl.text.trim(),
          newPin: _newPinCtrl.text.trim(),
        );

    if (mounted) {
      if (success) {
        _currentPinCtrl.clear();
        _newPinCtrl.clear();
        _confirmPinCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('4-Digit PIN successfully changed!'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        final err = ref.read(authProvider).errorMessage ?? 'Failed to change PIN.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmAndDeleteAccount() {
    final auth = ref.read(authProvider);
    final userName = auth.user?.name ?? auth.adminOperator?.fullName ?? 'User';

    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Delete Account Permanently',
        icon: Icons.delete_forever_rounded,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Warning: This action is permanent and cannot be undone.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to delete your account ($userName)? All active operator shift sessions will be terminated, and your account will be soft-deleted and deactivated on the server.',
                style: const TextStyle(fontSize: 13, height: 1.4),
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
            key: const ValueKey('confirm_delete_account_btn'),
            text: 'Delete My Account Forever',
            icon: Icons.delete_forever_rounded,
            variant: DossierButtonVariant.danger,
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(authProvider.notifier).deleteAccount();
              if (success && mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmAndSuspendOperator(KioskOperator op) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Suspend Operator: ${op.fullName}',
        icon: Icons.block_rounded,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suspending ${op.fullName} will immediately block them from PIN shift login and terminate any active sessions on this kiosk.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              DossierInputField(
                label: 'Reason for Suspension (Optional)',
                hintText: 'e.g. On leave / Shift inactive',
                controller: reasonCtrl,
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
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
            text: 'Suspend Operator',
            icon: Icons.block_rounded,
            variant: DossierButtonVariant.danger,
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).suspendOperator(
                    operatorId: op.id,
                    suspend: true,
                    reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                  );
            },
          ),
        ],
      ),
    );
  }

  void _showAddOperatorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => DossierDialog(
          title: 'Provision New Desk Operator',
          icon: Icons.person_add_alt_1_rounded,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Created operators are synchronized with the server and cached locally for rapid shift logins.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DossierInputField(
                  key: const ValueKey('admin_new_op_name'),
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
                        key: const ValueKey('admin_new_op_pin'),
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
                  key: const ValueKey('admin_new_op_phone'),
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

  void _showEditOperatorDialog(KioskOperator op) {
    final nameCtrl = TextEditingController(text: op.fullName);
    final phoneCtrl = TextEditingController(text: op.phone);
    final pinCtrl = TextEditingController(text: op.pin);
    OperatorRole role = op.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => DossierDialog(
          title: 'Edit Operator: ${op.fullName}',
          icon: Icons.edit_rounded,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DossierInputField(
                  label: 'Full Name',
                  controller: nameCtrl,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DossierInputField(
                        label: '4-Digit PIN',
                        controller: pinCtrl,
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
                            initialValue: role,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: OperatorRole.values.map((r) {
                              return DropdownMenuItem(value: r, child: Text(r.label, style: const TextStyle(fontSize: 12)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => role = val);
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
                  label: 'Mobile Number',
                  controller: phoneCtrl,
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
              text: 'Save Changes',
              icon: Icons.save_rounded,
              onPressed: () async {
                final success = await ref.read(authProvider.notifier).updateOperatorProfile(
                      operatorId: op.id,
                      fullName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      newPin: pinCtrl.text.trim(),
                      role: role,
                    );
                if (success && ctx.mounted) {
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
    final settings = ref.watch(kioskSettingsProvider);
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header & Tab Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 950;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Settings & User Profile',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'My Profile'),
                          Tab(text: 'Vault & Sync'),
                          Tab(text: 'Appearance'),
                          Tab(text: 'Kiosk Identity'),
                          Tab(text: 'Team & Operators'),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Workstation Settings & Profile Hub',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          const Text('Personal operator profiles, cloud vault sync, team administration, and hardware defaults',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 600,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.person_rounded, size: 15), text: 'My Profile'),
                          Tab(icon: Icon(Icons.cloud_sync_rounded, size: 15), text: 'Vault & Sync'),
                          Tab(icon: Icon(Icons.palette_rounded, size: 15), text: 'Appearance'),
                          Tab(icon: Icon(Icons.storefront_rounded, size: 15), text: 'Kiosk Profile'),
                          Tab(icon: Icon(Icons.badge_rounded, size: 15), text: 'Team & Operators'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserProfileTab(authState, isDark),
                const VaultSyncScreen(),
                _buildCurrencyThemeTab(settings, isDark),
                _buildKioskProfileTab(settings, authState, isDark),
                _buildTeamManagementTab(authState, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 1: Dedicated User Profile & Settings Page for Each Operator
  // ─────────────────────────────────────────────────────────────
  Widget _buildUserProfileTab(AuthState auth, bool isDark) {
    final curOp = auth.currentOperator ?? auth.adminOperator;
    final user = auth.user;

    if (curOp == null) {
      return const Center(child: Text('No active operator logged in.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Operator Identity & Status Card
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: curOp.role.color,
                          child: Text(
                            curOp.initials,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  curOp.fullName,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 8),
                                DossierBadge(
                                  label: curOp.role.label,
                                  variant: curOp.role == OperatorRole.admin
                                      ? DossierBadgeVariant.primary
                                      : DossierBadgeVariant.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Shift Operator ID: ${curOp.id}  •  ${curOp.kioskName}',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DossierButton(
                          text: 'End Shift / Switch',
                          icon: Icons.swap_horiz_rounded,
                          variant: DossierButtonVariant.outline,
                          size: DossierButtonSize.sm,
                          onPressed: () {
                            ref.read(authProvider.notifier).logout();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                          },
                        ),
                        DossierButton(
                          text: 'Sign Out Account',
                          icon: Icons.logout_rounded,
                          variant: DossierButtonVariant.danger,
                          size: DossierButtonSize.sm,
                          onPressed: () {
                            ref.read(authProvider.notifier).signOut();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildMetaMetric('Mobile Contact', curOp.phone.isNotEmpty ? curOp.phone : 'Not Linked', Icons.phone_android_rounded),
                    _buildMetaMetric('Email Address', curOp.email ?? user?.email ?? 'None', Icons.email_outlined),
                    _buildMetaMetric('Auth Provider', user?.provider.name.toUpperCase() ?? 'LOCAL PIN', Icons.security_rounded),
                    _buildMetaMetric('Last Shift Login', curOp.lastLoginAt != null ? curOp.lastLoginAt!.toLocal().toString().substring(0, 16) : 'Current Session', Icons.access_time_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Responsive 2-Column Grid: Edit Profile & Security
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 850;

              final editProfileCard = DossierCard(
                variant: DossierCardVariant.outlined,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text('Edit My Profile Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DossierInputField(
                      key: const ValueKey('profile_name_input'),
                      label: 'Full Name',
                      controller: _userFullNameCtrl,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      key: const ValueKey('profile_phone_input'),
                      label: 'Mobile Contact',
                      controller: _userPhoneCtrl,
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      key: const ValueKey('profile_email_input'),
                      label: 'Email Address (Optional)',
                      controller: _userEmailCtrl,
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DossierButton(
                        text: 'Save Profile',
                        icon: Icons.check_circle_rounded,
                        variant: DossierButtonVariant.primary,
                        size: DossierButtonSize.sm,
                        onPressed: _saveUserProfile,
                      ),
                    ),
                  ],
                ),
              );

              final changePinCard = DossierCard(
                variant: DossierCardVariant.outlined,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pin_rounded, size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text('Change 4-Digit Shift PIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DossierInputField(
                      key: const ValueKey('profile_cur_pin_input'),
                      label: 'Current 4-Digit PIN',
                      hintText: '****',
                      controller: _currentPinCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      key: const ValueKey('profile_new_pin_input'),
                      label: 'New 4-Digit PIN',
                      hintText: '****',
                      controller: _newPinCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.key_rounded, size: 18),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DossierInputField(
                      key: const ValueKey('profile_confirm_pin_input'),
                      label: 'Confirm New PIN',
                      hintText: '****',
                      controller: _confirmPinCtrl,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.check_rounded, size: 18),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DossierButton(
                        text: 'Update PIN',
                        icon: Icons.lock_reset_rounded,
                        variant: DossierButtonVariant.primary,
                        size: DossierButtonSize.sm,
                        onPressed: _handleChangePin,
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editProfileCard),
                    const SizedBox(width: 16),
                    Expanded(child: changePinCard),
                  ],
                );
              }

              return Column(
                children: [
                  editProfileCard,
                  const SizedBox(height: 16),
                  changePinCard,
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 3. Workplace & Hardware Preferences for this Operator
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print_rounded, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text('My Workplace & POS Hardware Defaults', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Include Operator Name on Thermal Receipts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Prints your name & shift ID at the bottom of customer receipts', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _includeOperatorOnReceipt,
                  onChanged: (val) => setState(() => _includeOperatorOnReceipt = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Automatic Paper Cut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Automatically cuts receipt roll after printing invoice', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _autoCutReceipt,
                  onChanged: (val) => setState(() => _autoCutReceipt = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Audio & Haptic Feedback on Quick Tender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Play chime when cash / UPI payment is finalized in POS pad', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _soundFeedback,
                  onChanged: (val) => setState(() => _soundFeedback = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thermal Slip Width Format', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Select your active printer roll width', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '58mm', label: Text('58mm (2")', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: '80mm', label: Text('80mm (3")', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_receiptPaperWidth},
                      onSelectionChanged: (set) => setState(() => _receiptPaperWidth = set.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Danger Zone & Account Deletion
          DossierCard(
            variant: DossierCardVariant.outlined,
            padding: const EdgeInsets.all(20),
            borderColor: Colors.red.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Danger Zone: Account Deletion',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Permanently delete your account, sign out all connected kiosk devices, and mark your profile as deleted on the server.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DossierButton(
                    key: const ValueKey('delete_account_btn'),
                    text: 'Delete Account & Data',
                    icon: Icons.delete_forever_rounded,
                    variant: DossierButtonVariant.danger,
                    size: DossierButtonSize.sm,
                    onPressed: _confirmAndDeleteAccount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaMetric(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6366F1)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 3: Currency & Appearance Theme
  // ─────────────────────────────────────────────────────────────
  Widget _buildCurrencyThemeTab(KioskSettings settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Appearance & Color Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      selected: settings.themeMode == ThemeMode.dark,
                      avatar: const Icon(Icons.dark_mode_rounded, size: 16),
                      label: const Text('Modern Dark Mode'),
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.dark),
                    ),
                    ChoiceChip(
                      selected: settings.themeMode == ThemeMode.light,
                      avatar: const Icon(Icons.light_mode_rounded, size: 16),
                      label: const Text('Crisp Light Mode'),
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.light),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Global Currency & Formatting', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Select your local currency for receipts, POS carts, and UPI links.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currencyPresets.map((c) {
                    final isSelected = settings.currencySymbol == c['symbol'] && settings.currencyCode == c['code'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(c['label']!),
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).updateCurrency(c['symbol']!, c['code']!),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 4: Kiosk Profile & Hardware / QR Settings
  // ─────────────────────────────────────────────────────────────
  Widget _buildKioskProfileTab(KioskSettings settings, AuthState auth, bool isDark) {
    final isAdmin = auth.currentOperator?.role == OperatorRole.admin || auth.user?.role == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Read-Only Mode: Center name, address, and merchant UPI ID can only be modified by the Administrator.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Kiosk Identity & Receipt Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                DossierInputField(
                  controller: _kioskNameCtrl,
                  readOnly: !isAdmin,
                  label: 'Kiosk / Cyber Center Name *',
                  hintText: 'e.g. Metro CSC Center',
                  prefixIcon: const Icon(Icons.store_rounded, size: 18),
                ),
                const SizedBox(height: 14),
                DossierInputField(
                  controller: _kioskPhoneCtrl,
                  readOnly: !isAdmin,
                  label: 'Public Contact Number *',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
                const SizedBox(height: 14),
                DossierInputField(
                  controller: _kioskAddressCtrl,
                  readOnly: !isAdmin,
                  label: 'Center Physical Address',
                  hintText: 'e.g. Shop 4, Main Market, Civil Lines',
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                ),
                const SizedBox(height: 14),
                DossierInputField(
                  controller: _upiVpaCtrl,
                  readOnly: !isAdmin,
                  label: 'Merchant UPI ID *',
                  hintText: 'e.g. yourshop@oksbi',
                  prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DossierButton(
                      text: 'Save Kiosk Profile',
                      icon: Icons.save_rounded,
                      variant: DossierButtonVariant.primary,
                      size: DossierButtonSize.md,
                      onPressed: _saveKioskProfile,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 5: Team & Operators (ADMIN ONLY)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTeamManagementTab(AuthState auth, bool isDark) {
    final isAdmin = auth.currentOperator?.role == OperatorRole.admin || auth.user?.role == 'admin';
    final operators = auth.registeredOperators;

    if (!isAdmin) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, size: 36, color: Color(0xFF6366F1)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin Authorization Required',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only the Kiosk Administrator / Owner can provision, edit, and deactivate desk operator accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kiosk Operator Team Roster',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Manage desk counter operators, assign roles, and configure 4-digit PINs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              DossierButton(
                text: 'Provision Operator',
                icon: Icons.person_add_rounded,
                variant: DossierButtonVariant.primary,
                size: DossierButtonSize.sm,
                onPressed: _showAddOperatorDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: operators.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final op = operators[i];
              final isMasterAdmin = op.id == auth.adminOperator?.id;

              return DossierCard(
                variant: DossierCardVariant.outlined,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: op.role.color,
                      child: Text(op.initials, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(op.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              DossierBadge(
                                label: op.role.label,
                                variant: op.role == OperatorRole.admin ? DossierBadgeVariant.primary : DossierBadgeVariant.neutral,
                              ),
                              if (op.isSuspended)
                                const DossierBadge(
                                  label: 'SUSPENDED',
                                  variant: DossierBadgeVariant.warning,
                                  icon: Icons.block_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Phone: ${op.phone.isNotEmpty ? op.phone : "None"} • PIN: •••• • Added: ${op.createdAt.toLocal().toString().substring(0, 10)}${op.isSuspended && op.suspendedReason != null ? " • Reason: ${op.suspendedReason}" : ""}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMasterAdmin) ...[
                          if (op.isSuspended)
                            IconButton(
                              icon: const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF10B981)),
                              tooltip: 'Unsuspend Operator',
                              onPressed: () async {
                                await ref.read(authProvider.notifier).suspendOperator(
                                      operatorId: op.id,
                                      suspend: false,
                                    );
                              },
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.block_rounded, size: 18, color: Color(0xFFF59E0B)),
                              tooltip: 'Suspend Operator',
                              onPressed: () => _confirmAndSuspendOperator(op),
                            ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          tooltip: 'Edit Operator',
                          onPressed: () => _showEditOperatorDialog(op),
                        ),
                        if (!isMasterAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            tooltip: 'Remove Operator',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove Operator?'),
                                  content: Text('Are you sure you want to remove ${op.fullName}? They will no longer be able to log in to this kiosk.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(authProvider.notifier).deleteOperator(operatorId: op.id);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
