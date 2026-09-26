import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
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

    return Dialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 750),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.settings_suggest_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.existingService != null ? 'Edit Service & Cost Breakdown' : 'Create New Custom Service',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Name
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Service Name *',
                          hintText: 'e.g. Fresh Passport Seva Application',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Service name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Service Category',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: _availableCategories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['key'],
                            child: Text(c['label']!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cost Breakup Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Granular Cost & Margin Breakup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _portalFeeController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      labelText: 'Govt Portal Cost ($currencySymbol)',
                                      helperText: 'Pass-through fee paid to govt portal',
                                      prefixText: '$currencySymbol ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _serviceFeeController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      labelText: 'Kiosk Counter Profit ($currencySymbol)',
                                      helperText: 'Your shop fee for processing / typing',
                                      prefixText: '$currencySymbol ',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Required Documents Checklist Manager
                      const Text(
                        'Required Documents Checklist (Auto-merged into Case Intake):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                            child: TextField(
                              controller: _newDocController,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              decoration: const InputDecoration(
                                hintText: 'Type custom document name (e.g. Birth Certificate)...',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addCustomDoc(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _addCustomDoc,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Doc'),
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
                          title: const Text('Archive / Disable this service'),
                          subtitle: const Text('Archived services will not appear in walk-in case selector'),
                          value: _isArchived,
                          onChanged: (val) => setState(() => _isArchived = val),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(widget.existingService != null ? 'Save Changes' : 'Create Service'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
