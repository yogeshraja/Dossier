import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:uuid/uuid.dart';

class NewDossierDialog extends ConsumerStatefulWidget {
  const NewDossierDialog({super.key});

  @override
  ConsumerState<NewDossierDialog> createState() => _NewDossierDialogState();
}

class _NewDossierDialogState extends ConsumerState<NewDossierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final newId = const Uuid().v4();

      await db.insertDossier(
        DossiersCompanion.insert(
          id: newId,
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? drift.Value(_emailController.text.trim()) : const drift.Value.absent(),
          notes: _notesController.text.trim().isNotEmpty ? drift.Value(_notesController.text.trim()) : const drift.Value.absent(),
        ),
      );

      ref.read(activeDossierIdProvider.notifier).state = newId;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "${_nameController.text.trim()}" created successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving customer: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DossierDialog(
      title: 'New Customer Dossier',
      subtitle: 'Create a permanent offline record & case vault',
      icon: Icons.person_add_rounded,
      iconColor: const Color(0xFF6366F1),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DossierInputField(
              controller: _phoneController,
              label: 'Phone Number *',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_rounded, size: 18),
              keyboardType: TextInputType.phone,
              autofocus: true,
              showClearButton: true,
              validator: (val) {
                if (val == null || val.trim().length < 10) {
                  return 'Please enter a valid phone number (min 10 digits)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DossierInputField(
              controller: _nameController,
              label: 'Customer Full Name *',
              hintText: 'e.g. Rajesh Kumar',
              prefixIcon: const Icon(Icons.badge_rounded, size: 18),
              showClearButton: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Customer name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DossierInputField(
              controller: _emailController,
              label: 'Email Address (Optional)',
              hintText: 'e.g. rajesh@example.com',
              prefixIcon: const Icon(Icons.email_rounded, size: 18),
              keyboardType: TextInputType.emailAddress,
              showClearButton: true,
            ),
            const SizedBox(height: 16),
            DossierInputField(
              controller: _notesController,
              label: 'Operator Notes / Preferences',
              hintText: 'e.g. Prefers WhatsApp receipt alerts',
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              maxLines: 2,
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
          text: 'Create Dossier',
          variant: DossierButtonVariant.primary,
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
