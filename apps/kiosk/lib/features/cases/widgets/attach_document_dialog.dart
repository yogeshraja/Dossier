import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:uuid/uuid.dart';

class AttachDocumentDialog extends ConsumerStatefulWidget {
  final String caseId;
  final String? initialSlotType;

  const AttachDocumentDialog({
    super.key,
    required this.caseId,
    this.initialSlotType,
  });

  @override
  ConsumerState<AttachDocumentDialog> createState() => _AttachDocumentDialogState();
}

class _AttachDocumentDialogState extends ConsumerState<AttachDocumentDialog> {
  static const _commonDocSlots = [
    'Aadhaar Front',
    'Aadhaar Back',
    'Passport Photo',
    'Signature',
    'PAN Card',
    'Income Certificate',
    'Address Proof',
    'Application Form',
    'Bank Passbook',
    'Payment Receipt',
    'Custom Document',
  ];

  late String _selectedSlot;
  final _customSlotCtrl = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.initialSlotType ?? _commonDocSlots.first;
  }

  @override
  void dispose() {
    _customSlotCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp', 'bmp', 'tiff'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveAttachments() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one file to attach.')),
      );
      return;
    }

    final effectiveSlot = _selectedSlot == 'Custom Document' && _customSlotCtrl.text.trim().isNotEmpty
        ? _customSlotCtrl.text.trim()
        : _selectedSlot;

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      const uuid = Uuid();

      for (final file in _selectedFiles) {
        final ext = file.extension ?? 'jpg';
        final mime = _getMimeType(ext);
        final size = file.size;
        final name = file.name;
        final path = file.path;

        await db.insertExhibit(
          ExhibitsCompanion.insert(
            id: uuid.v4(),
            caseId: widget.caseId,
            slotType: effectiveSlot,
            fileName: name,
            mimeType: mime,
            fileSizeBytes: size,
            localPath: path != null ? drift.Value(path) : const drift.Value.absent(),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully attached ${_selectedFiles.length} document(s)!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attachment: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DossierDialog(
      title: 'Attach Case Documents',
      subtitle: 'Browse real scans, photo captures, or PDF exhibits from device',
      icon: Icons.attach_file_rounded,
      iconColor: const Color(0xFF6366F1),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Document Slot Category
              const Text(
                'Document Classification / Slot:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _commonDocSlots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedSlot = slot);
                    },
                  );
                }).toList(),
              ),

              if (_selectedSlot == 'Custom Document') ...[
                const SizedBox(height: 10),
                DossierInputField(
                  controller: _customSlotCtrl,
                  label: 'Custom Document Name *',
                  hintText: 'e.g. Affidavit / Caste Certificate',
                  prefixIcon: const Icon(Icons.description_rounded, size: 18),
                ),
              ],

              const SizedBox(height: 18),

              // File Picker Action Area
              InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.file_upload_outlined,
                          size: 32,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Click to Browse & Attach Real Files',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports JPG, PNG, PDF, WebP, BMP scans and exhibits',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Selected Files List
              if (_selectedFiles.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Files (${_selectedFiles.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Add More', style: TextStyle(fontSize: 12)),
                      onPressed: _pickFiles,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedFiles.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(file.extension?.toLowerCase());

                    return DossierCard(
                      variant: DossierCardVariant.flat,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      borderRadius: 10,
                      child: Row(
                        children: [
                          if (isImage && file.path != null && File(file.path!).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(file.path!),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                file.extension?.toLowerCase() == 'pdf'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.insert_drive_file_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${file.extension?.toUpperCase() ?? "FILE"} • ${_formatFileSize(file.size)}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                            tooltip: 'Remove file',
                            onPressed: () {
                              setState(() {
                                _selectedFiles.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        DossierButton(
          text: 'Cancel',
          variant: DossierButtonVariant.outline,
          size: DossierButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DossierButton(
          text: 'Attach ${_selectedFiles.isNotEmpty ? "(${_selectedFiles.length})" : ""}',
          icon: Icons.check_circle_rounded,
          variant: DossierButtonVariant.primary,
          size: DossierButtonSize.sm,
          isLoading: _isSaving,
          onPressed: _selectedFiles.isNotEmpty ? _saveAttachments : null,
        ),
      ],
    );
  }
}
