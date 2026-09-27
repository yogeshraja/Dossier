import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

class ExhibitPreviewDialog extends ConsumerStatefulWidget {
  final Exhibit exhibit;

  const ExhibitPreviewDialog({super.key, required this.exhibit});

  @override
  ConsumerState<ExhibitPreviewDialog> createState() => _ExhibitPreviewDialogState();
}

class _ExhibitPreviewDialogState extends ConsumerState<ExhibitPreviewDialog> {
  bool _isDeleting = false;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _openExternal() async {
    final path = widget.exhibit.localPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local file path recorded for this exhibit.')),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File not found on disk at: $path'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Delete Attachment?',
        subtitle: 'Are you sure you want to remove "${widget.exhibit.fileName}" from this case?',
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.redAccent,
        content: const Text(
          'This will permanently remove the exhibit record from the case intake database.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          DossierButton(
            text: 'Cancel',
            variant: DossierButtonVariant.outline,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DossierButton(
            text: 'Delete Exhibit',
            variant: DossierButtonVariant.danger,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final db = ref.read(databaseProvider);
      await db.deleteExhibit(widget.exhibit.id);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exhibit deleted successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting exhibit: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = widget.exhibit.localPath;
    final hasLocalFile = path != null && path.isNotEmpty && File(path).existsSync();
    final isImage = widget.exhibit.mimeType.startsWith('image/');
    final isPdf = widget.exhibit.mimeType.contains('pdf') || widget.exhibit.fileName.toLowerCase().endsWith('.pdf');

    return DossierDialog(
      title: widget.exhibit.slotType,
      subtitle: widget.exhibit.fileName,
      icon: isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
      iconColor: const Color(0xFF6366F1),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Metadata Pills
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  DossierBadge(
                    label: widget.exhibit.slotType,
                    variant: DossierBadgeVariant.primary,
                  ),
                  DossierBadge(
                    label: _formatFileSize(widget.exhibit.fileSizeBytes),
                    variant: DossierBadgeVariant.neutral,
                  ),
                  DossierBadge(
                    label: isPdf ? 'PDF DOCUMENT' : 'IMAGE',
                    variant: isPdf ? DossierBadgeVariant.warning : DossierBadgeVariant.success,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Preview Surface
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 340, minHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Center(
                  child: hasLocalFile
                      ? (isImage
                          ? InteractiveViewer(
                              panEnabled: true,
                              boundaryMargin: const EdgeInsets.all(20),
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 56, color: Colors.redAccent),
                                const SizedBox(height: 12),
                                Text(
                                  widget.exhibit.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap "Open Document" below to view in system PDF reader',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey[500]),
                            const SizedBox(height: 8),
                            const Text('No local file cached on this terminal', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            if (path != null && path.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                                child: Text(
                                  path,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),
              if (path != null && path.isNotEmpty)
                Text(
                  'Local Path: $path',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
      actions: [
        DossierButton(
          text: 'Delete',
          icon: Icons.delete_outline_rounded,
          variant: DossierButtonVariant.danger,
          size: DossierButtonSize.sm,
          isLoading: _isDeleting,
          onPressed: _handleDelete,
        ),
        if (hasLocalFile)
          DossierButton(
            text: 'Open Document',
            icon: Icons.open_in_new_rounded,
            variant: DossierButtonVariant.secondary,
            size: DossierButtonSize.sm,
            onPressed: _openExternal,
          ),
        DossierButton(
          text: 'Close',
          variant: DossierButtonVariant.outline,
          size: DossierButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
