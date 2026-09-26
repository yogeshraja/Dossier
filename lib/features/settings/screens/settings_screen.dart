import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/settings/widgets/edit_service_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _kioskNameCtrl = TextEditingController();
  final _kioskPhoneCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _upiVpaCtrl = TextEditingController();

  static const _categoryLabels = {
    'GOVT_SCHEME': 'Government Schemes',
    'PRINTING': 'Printing & Xerox',
    'CERTIFICATE': 'Certificates & Affidavits',
    'UTILITY': 'Utility & Bill Payments',
    'LEGAL': 'Legal & Typing',
    'FINANCIAL': 'Financial Services',
  };

  static const _currencyPresets = [
    {'symbol': '₹', 'code': 'INR', 'label': 'Indian Rupee (₹ INR)'},
    {'symbol': '\$', 'code': 'USD', 'label': 'US Dollar (\$ USD)'},
    {'symbol': '€', 'code': 'EUR', 'label': 'Euro (€ EUR)'},
    {'symbol': '£', 'code': 'GBP', 'label': 'British Pound (£ GBP)'},
    {'symbol': 'AED', 'code': 'AED', 'label': 'UAE Dirham (AED)'},
    {'symbol': 'SAR', 'code': 'SAR', 'label': 'Saudi Riyal (SAR)'},
    {'symbol': '৳', 'code': 'BDT', 'label': 'Bangladeshi Taka (৳ BDT)'},
    {'symbol': '₨', 'code': 'PKR', 'label': 'Pakistani Rupee (₨ PKR)'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final settings = ref.read(kioskSettingsProvider);
    _kioskNameCtrl.text = settings.kioskName;
    _kioskPhoneCtrl.text = settings.kioskPhone;
    _kioskAddressCtrl.text = settings.kioskAddress;
    _upiVpaCtrl.text = settings.merchantUpiVpa;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kioskNameCtrl.dispose();
    _kioskPhoneCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _upiVpaCtrl.dispose();
    super.dispose();
  }

  void _saveKioskProfile() {
    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: _kioskNameCtrl.text.trim(),
          address: _kioskAddressCtrl.text.trim(),
          phone: _kioskPhoneCtrl.text.trim(),
          upiVpa: _upiVpaCtrl.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kiosk Profile & Receipt Headers updated!'), backgroundColor: Color(0xFF10B981)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catalog Customization & Kiosk Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const Text('Configure service fee breakups, document checklists, currency, and themes',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 480,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(icon: Icon(Icons.format_list_bulleted_rounded, size: 16), text: 'Services Catalog'),
                      Tab(icon: Icon(Icons.currency_exchange_rounded, size: 16), text: 'Currency & Theme'),
                      Tab(icon: Icon(Icons.storefront_rounded, size: 16), text: 'Kiosk Profile & QR'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServicesCatalogTab(settings, isDark),
                _buildCurrencyThemeTab(settings, isDark),
                _buildKioskProfileTab(settings, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Services Catalog & Opt-ins ---
  Widget _buildServicesCatalogTab(KioskSettings settings, bool isDark) {
    final servicesAsync = ref.watch(activeServicesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Opt-ins Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Service Category Opt-Ins (Toggle to Show/Hide in Kiosk):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _categoryLabels.entries.map((entry) {
                    final isOptedIn = settings.activeCategories.contains(entry.key);
                    return FilterChip(
                      selected: isOptedIn,
                      label: Text(entry.value),
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).toggleCategory(entry.key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Services Table Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Configured Master Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const EditServiceDialog(),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Custom Service'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Services List
          Expanded(
            child: servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return const Center(child: Text('No services configured'));
                }

                return ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    List<dynamic> docs = [];
                    try {
                      docs = jsonDecode(s.requiredDocsJson);
                    } catch (_) {}

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.description_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _categoryLabels[s.category] ?? s.category,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                                      ),
                                    ),
                                    if (s.isArchived) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ARCHIVED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Portal Fee: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)}  •  Shop Fee: ${settings.currencySymbol}${s.defaultServiceFee.toStringAsFixed(0)}  •  Total: ${settings.currencySymbol}${(s.defaultPortalFee + s.defaultServiceFee).toStringAsFixed(0)}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                if (docs.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Required Docs: ${docs.join(", ")}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            tooltip: 'Edit Service & Pricing',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => EditServiceDialog(existingService: s),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading services: $err')),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: Currency & Theme Customization ---
  Widget _buildCurrencyThemeTab(KioskSettings settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Mode Switcher
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Appearance & Color Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.dark),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: settings.themeMode == ThemeMode.dark ? const Color(0xFF818CF8) : const Color(0xFF334155),
                              width: settings.themeMode == ThemeMode.dark ? 2 : 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.dark_mode_rounded, color: Color(0xFF818CF8)),
                              SizedBox(width: 12),
                              Text('Modern Dark Theme (Default)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.light),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: settings.themeMode == ThemeMode.light ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                              width: settings.themeMode == ThemeMode.light ? 2 : 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.light_mode_rounded, color: Color(0xFF4F46E5)),
                              SizedBox(width: 12),
                              Text('Crisp Light Theme', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Currency Customizer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Global Currency & Formatting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Select your local currency symbol and ISO code for receipts, POS carts, and UPI links.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: _currencyPresets.map((c) {
                    final isSelected = settings.currencySymbol == c['symbol'] && settings.currencyCode == c['code'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(c['label']!),
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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

  // --- Tab 3: Kiosk Profile & Hardware / QR Settings ---
  Widget _buildKioskProfileTab(KioskSettings settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_rounded, size: 20),
                SizedBox(width: 10),
                Text('Kiosk Identity & Receipt Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _kioskNameCtrl,
              decoration: const InputDecoration(labelText: 'Kiosk / Cyber Center Name *', prefixIcon: Icon(Icons.store)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kioskPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Public Contact Number *', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kioskAddressCtrl,
              decoration: const InputDecoration(labelText: 'Center Physical Address', prefixIcon: Icon(Icons.location_on)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _upiVpaCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant UPI ID (For Dynamic QR Code) *',
                hintText: 'e.g. yourshop@oksbi / yourshop@paytm',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveKioskProfile,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Kiosk Configuration'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
