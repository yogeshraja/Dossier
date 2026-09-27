import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:uuid/uuid.dart';

class EditServiceDialog extends ConsumerStatefulWidget {
  final Service? existingService;
  const EditServiceDialog({super.key, this.existingService});

  @override
  ConsumerState<EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends ConsumerState<EditServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _portalFeeController = TextEditingController(text: '0');
  final _serviceFeeController = TextEditingController(text: '50');
  final _newDocController = TextEditingController();

  String _selectedCategory = 'GOVT_SCHEME';
  List<String> _requiredDocs = [];
  bool _isArchived = false;
  bool _isSaving = false;

  static const _availableCategories = [
    {'key': 'GOVT_SCHEME', 'label': 'Government Scheme / Portal'},
    {'key': 'PRINTING', 'label': 'Printing, Xerox & Lamination'},
    {'key': 'CERTIFICATE', 'label': 'Certificates & Affidavits'},
    {'key': 'UTILITY', 'label': 'Utility & Bill Payments'},
    {'key': 'LEGAL', 'label': 'Legal & Typing Documents'},
    {'key': 'FINANCIAL', 'label': 'Banking & Financial Services'},
  ];

  static const _commonDocPresets = [
    'Aadhaar Card (Front & Back)',
    'Passport Size Photo',
    'Customer Signature',
    'Proof of Address (Electricity/Gas Bill)',
    'Ration Card',
    'Salary Slip / Income Proof',
    'Pan Card Copy',
    'Voter ID Card',
    'Bank Passbook Copy',
    'Educational Certificate',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      final s = widget.existingService!;
      _nameController.text = s.name;
      _selectedCategory = s.category;
      _portalFeeController.text = s.defaultPortalFee.toStringAsFixed(0);
      _serviceFeeController.text = s.defaultServiceFee.toStringAsFixed(0);
      _isArchived = s.isArchived;
      try {
        final List<dynamic> parsed = jsonDecode(s.requiredDocsJson);
        _requiredDocs = parsed.map((e) => e.toString()).toList();
      } catch (_) {
        _requiredDocs = [];
      }
    } else {
      _requiredDocs = ['Aadhaar Card (Front & Back)', 'Passport Size Photo'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portalFeeController.dispose();
    _serviceFeeController.dispose();
    _newDocController.dispose();
    super.dispose();
  }

  void _addCustomDoc() {
    final text = _newDocController.text.trim();
    if (text.isNotEmpty && !_requiredDocs.contains(text)) {
      setState(() {
        _requiredDocs.add(text);
        _newDocController.clear();
      });
    }
  }

  void _togglePresetDoc(String doc) {
    setState(() {
      if (_requiredDocs.contains(doc)) {
        _requiredDocs.remove(doc);
      } else {
        _requiredDocs.add(doc);
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final portalFee = double.tryParse(_portalFeeController.text.trim()) ?? 0.0;
      final serviceFee = double.tryParse(_serviceFeeController.text.trim()) ?? 0.0;
      final jsonDocs = jsonEncode(_requiredDocs);

      if (widget.existingService != null) {
        // Update existing service
        await (db.update(db.services)..where((s) => s.id.equals(widget.existingService!.id))).write(
          ServicesCompanion(
            name: drift.Value(_nameController.text.trim()),
            category: drift.Value(_selectedCategory),
            defaultPortalFee: drift.Value(portalFee),
            defaultServiceFee: drift.Value(serviceFee),
            requiredDocsJson: drift.Value(jsonDocs),
            isArchived: drift.Value(_isArchived),
          ),
        );
      } else {
        // Insert new custom service
        await db.insertService(
          ServicesCompanion.insert(
            id: const Uuid().v4(),
            name: _nameController.text.trim(),
            category: _selectedCategory,
            defaultPortalFee: drift.Value(portalFee),
            defaultServiceFee: drift.Value(serviceFee),
            requiredDocsJson: drift.Value(jsonDocs),
            isArchived: drift.Value(_isArchived),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingService != null ? 'Service updated successfully!' : 'New service created!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving service: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(kioskSettingsProvider).currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DossierDialog(
      title: widget.existingService != null ? 'Edit Service & Cost Breakdown' : 'Create New Custom Service',
      subtitle: 'Configure pricing, pass-through fees and document requirements',
      icon: Icons.settings_suggest_rounded,
      maxWidth: 700,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Service Name
            DossierInputField(
              controller: _nameController,
              label: 'Service Name *',
              hintText: 'e.g. Fresh Passport Seva Application',
              prefixIcon: const Icon(Icons.badge_rounded, size: 18),
              showClearButton: true,
              validator: (val) => val == null || val.trim().isEmpty ? 'Service name is required' : null,
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Text(
              'Service Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: Theme.of(context).cardTheme.color,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.category_rounded, size: 18),
              ),
              items: _availableCategories.map((c) {
                return DropdownMenuItem<String>(
                  value: c['key'],
                  child: Text(c['label']!, style: const TextStyle(fontSize: 13.5)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),

            // Cost Breakup Section
            DossierCard(
              variant: DossierCardVariant.flat,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Granular Cost & Margin Breakup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DossierInputField(
                          controller: _portalFeeController,
                          keyboardType: TextInputType.number,
                          label: 'Govt Portal Cost ($currencySymbol)',
                          helperText: 'Pass-through fee paid to portal',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: Text(
                                currencySymbol,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DossierInputField(
                          controller: _serviceFeeController,
                          keyboardType: TextInputType.number,
                          label: 'Kiosk Counter Profit ($currencySymbol)',
                          helperText: 'Your shop fee for processing',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: Text(
                                currencySymbol,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Required Documents Checklist Manager
            const Text(
              'Required Documents Checklist (Auto-merged into Case Intake):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),

            // Selected Doc Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _requiredDocs.map((doc) {
                return Chip(
                  label: Text(doc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _requiredDocs.remove(doc)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Add Custom Doc Tag
            Row(
              children: [
                Expanded(
                  child: DossierInputField(
                    controller: _newDocController,
                    hintText: 'Type custom document name (e.g. Birth Certificate)...',
                    onFieldSubmitted: (_) => _addCustomDoc(),
                  ),
                ),
                const SizedBox(width: 8),
                DossierButton(
                  text: 'Add Doc',
                  icon: Icons.add_rounded,
                  variant: DossierButtonVariant.secondary,
                  size: DossierButtonSize.md,
                  onPressed: _addCustomDoc,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Preset Document Adders
            const Text('Quick Add Presets:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _commonDocPresets.where((p) => !_requiredDocs.contains(p)).map((preset) {
                return ActionChip(
                  label: Text('+ $preset', style: const TextStyle(fontSize: 11)),
                  onPressed: () => _togglePresetDoc(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Archive Status Switch
            if (widget.existingService != null)
              SwitchListTile(
                title: const Text('Archive / Disable this service', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Archived services will not appear in walk-in case selector', style: TextStyle(fontSize: 12)),
                value: _isArchived,
                onChanged: (val) => setState(() => _isArchived = val),
              ),
          ],
        ),
      ),
      actions: [
        DossierButton(
          text: 'Cancel',
          variant: DossierButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 10),
        DossierButton(
          text: widget.existingService != null ? 'Save Changes' : 'Create Service',
          variant: DossierButtonVariant.primary,
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
