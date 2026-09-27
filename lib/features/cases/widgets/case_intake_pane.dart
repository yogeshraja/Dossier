import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/cases/widgets/new_case_dialog.dart';
import 'package:dossier/features/cases/widgets/attach_document_dialog.dart';
import 'package:dossier/features/cases/widgets/exhibit_preview_dialog.dart';
import 'package:dossier/features/billing_pos/widgets/record_payment_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_panel.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';

class CaseIntakePane extends ConsumerWidget {
  const CaseIntakePane({super.key});

  static const _stages = [
    {'key': 'DRAFT', 'label': 'Draft', 'icon': Icons.edit_note_rounded},
    {'key': 'DOCS_PENDING', 'label': 'Docs Pending', 'icon': Icons.pending_actions_rounded},
    {'key': 'READY_TO_APPLY', 'label': 'Ready to Apply', 'icon': Icons.fact_check_rounded},
    {'key': 'SUBMITTED', 'label': 'Submitted', 'icon': Icons.cloud_upload_rounded},
    {'key': 'READY_FOR_PICKUP', 'label': 'Ready for Pickup', 'icon': Icons.assignment_turned_in_rounded},
    {'key': 'CLOSED', 'label': 'Closed', 'icon': Icons.check_circle_rounded},
  ];

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'DRAFT':
        return Colors.grey;
      case 'DOCS_PENDING':
        return Colors.orangeAccent;
      case 'READY_TO_APPLY':
        return Colors.cyan;
      case 'SUBMITTED':
        return Colors.blueAccent;
      case 'READY_FOR_PICKUP':
        return const Color(0xFF10B981);
      case 'CLOSED':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStage(WidgetRef ref, String caseId, String newStage) async {
    final db = ref.read(databaseProvider);
    await db.updateCaseStage(caseId, newStage);
  }

  void _openAttachDialog(BuildContext context, String caseId, [String? initialSlot]) {
    DossierDialog.show(
      context: context,
      builder: (_) => AttachDocumentDialog(caseId: caseId, initialSlotType: initialSlot),
    );
  }

  void _openExhibitPreview(BuildContext context, Exhibit exhibit) {
    DossierDialog.show(
      context: context,
      builder: (_) => ExhibitPreviewDialog(exhibit: exhibit),
    );
  }

  void _confirmDeleteCase(BuildContext context, WidgetRef ref, Case c) {
    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Delete Case',
        icon: Icons.warning_amber_rounded,
        content: Text(
          'Are you sure you want to permanently delete the case "${c.title}"? All associated exhibits will be removed.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          DossierButton(
            text: 'Cancel',
            variant: DossierButtonVariant.outline,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          DossierButton(
            text: 'Delete Case',
            variant: DossierButtonVariant.danger,
            icon: Icons.delete_forever_rounded,
            size: DossierButtonSize.sm,
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteCase(c.id);
              ref.read(activeCaseIdProvider.notifier).state = null;
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, WidgetRef ref, Dossier d) {
    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Delete Customer Dossier',
        icon: Icons.warning_amber_rounded,
        content: Text(
          'Are you sure you want to delete customer "${d.fullName}" (${d.phoneNumber})? All cases and documents for this customer will be removed.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          DossierButton(
            text: 'Cancel',
            variant: DossierButtonVariant.outline,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          DossierButton(
            text: 'Delete Customer',
            variant: DossierButtonVariant.danger,
            icon: Icons.delete_forever_rounded,
            size: DossierButtonSize.sm,
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteDossier(d.id);
              ref.read(activeDossierIdProvider.notifier).state = null;
              ref.read(activeCaseIdProvider.notifier).state = null;
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDossier = ref.watch(activeDossierProvider);
    final activeCasesAsync = ref.watch(activeCasesStreamProvider);
    final activeCase = ref.watch(activeCaseProvider);
    final exhibitsAsync = ref.watch(activeCaseExhibitsStreamProvider);
    final isBillingExpanded = ref.watch(isBillingHubExpandedProvider);
    final settings = ref.watch(kioskSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeDossier == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_shared_outlined, size: 48, color: Colors.grey[500]),
              const SizedBox(height: 12),
              Text(
                'Select a customer dossier from the directory to view or create cases',
                style: TextStyle(color: Colors.grey[500], fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Customer Profile Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          activeDossier.fullName.isNotEmpty ? activeDossier.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeDossier.fullName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const DossierBadge(
                              label: 'ACTIVE',
                              variant: DossierBadgeVariant.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${activeDossier.phoneNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DossierButton(
                      text: 'New Case Intake',
                      icon: Icons.add_rounded,
                      size: DossierButtonSize.sm,
                      variant: DossierButtonVariant.primary,
                      onPressed: () {
                        DossierDialog.show(
                          context: context,
                          builder: (_) => NewCaseDialog(customer: activeDossier),
                        );
                      },
                    ),
                    if (!isBillingExpanded) ...[
                      const SizedBox(width: 8),
                      DossierButton(
                        text: 'Billing Hub',
                        icon: Icons.point_of_sale_rounded,
                        size: DossierButtonSize.sm,
                        variant: DossierButtonVariant.secondary,
                        onPressed: () => ref.read(isBillingHubExpandedProvider.notifier).state = true,
                      ),
                    ],
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                      tooltip: 'Delete Customer Dossier',
                      onPressed: () => _confirmDeleteCustomer(context, ref, activeDossier),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Cases Workspace
          Expanded(
            child: activeCasesAsync.when(
              data: (cases) {
                if (cases.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey[500]),
                          const SizedBox(height: 10),
                          const Text('No active cases for this customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Tap "New Case Intake" above to start a service application', style: TextStyle(color: Colors.grey[500], fontSize: 12.5)),
                        ],
                      ),
                    ),
                  );
                }

                // Horizontal Case Tabs
                return Column(
                  children: [
                    Container(
                      height: 48,
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        itemCount: cases.length,
                        separatorBuilder: (context, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final c = cases[index];
                          final isSelected = activeCase?.id == c.id;

                          return ChoiceChip(
                            label: Text(
                              c.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => ref.read(activeCaseIdProvider.notifier).state = c.id,
                            selectedColor: Theme.of(context).colorScheme.primary,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                            ),
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),

                    // Active Case Details & Stepper
                    if (activeCase != null)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stage Lifecycle Stepper
                              const Text('Lifecycle Stage Progression:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _stages.map((st) {
                                    final isCurrent = activeCase.stage == st['key'];
                                    final isPassed = _stages.indexWhere((s) => s['key'] == activeCase.stage) >= _stages.indexOf(st);
                                    final stageColor = _getStageColor(st['key'] as String);

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: ActionChip(
                                        avatar: Icon(
                                          st['icon'] as IconData,
                                          size: 14,
                                          color: isCurrent ? Colors.white : (isPassed ? stageColor : Colors.grey),
                                        ),
                                        label: Text(
                                          st['label'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            color: isCurrent ? Colors.white : (isPassed ? stageColor : Colors.grey),
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: isCurrent ? stageColor.withValues(alpha: 0.8) : Theme.of(context).cardTheme.color,
                                        side: BorderSide(color: isCurrent ? stageColor : Theme.of(context).dividerColor),
                                        onPressed: () => _updateStage(ref, activeCase.id, st['key'] as String),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Financial Overview Card
                              DossierCard(
                                variant: DossierCardVariant.glass,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceAround,
                                      runAlignment: WrapAlignment.center,
                                      spacing: 16,
                                      runSpacing: 12,
                                      children: [
                                        _buildStatItem('Govt Portal Cost', '${settings.currencySymbol}${activeCase.totalPortalFee.toStringAsFixed(0)}', Colors.grey[500]!),
                                        _buildStatItem('Kiosk Profit', '${settings.currencySymbol}${activeCase.totalServiceFee.toStringAsFixed(0)}', Theme.of(context).colorScheme.primary),
                                        _buildStatItem('Total Estimate', '${settings.currencySymbol}${activeCase.totalEstimatedAmount.toStringAsFixed(0)}', Theme.of(context).colorScheme.onSurface),
                                        _buildStatItem('Advance Paid', '${settings.currencySymbol}${activeCase.advancePaid.toStringAsFixed(0)}', const Color(0xFF10B981)),
                                        _buildStatItem(
                                          'Balance Due',
                                          '${settings.currencySymbol}${(activeCase.totalEstimatedAmount - activeCase.advancePaid).clamp(0, 99999).toStringAsFixed(0)}',
                                          Colors.amber,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Case ID: ${activeCase.id.substring(0, 8).toUpperCase()}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace'),
                                        ),
                                        DossierButton(
                                          text: 'Collect Payment',
                                          icon: Icons.payments_rounded,
                                          size: DossierButtonSize.sm,
                                          variant: DossierButtonVariant.success,
                                          onPressed: () {
                                            DossierDialog.show(
                                              context: context,
                                              builder: (_) => RecordPaymentDialog(caseItem: activeCase, customer: activeDossier),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Document Exhibits Slot Manager via DossierPanel
                              DossierPanel(
                                title: 'Case Exhibits & Scanned Artifacts',
                                subtitle: 'Local document vault & exhibits repository',
                                leading: const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF6366F1)),
                                badge: exhibitsAsync.maybeWhen(
                                  data: (ex) => DossierBadge(label: '${ex.length}', variant: DossierBadgeVariant.neutral),
                                  orElse: () => null,
                                ),
                                actions: [
                                  DossierButton(
                                    text: 'Attach Document',
                                    icon: Icons.attach_file_rounded,
                                    size: DossierButtonSize.sm,
                                    variant: DossierButtonVariant.primary,
                                    onPressed: () => _openAttachDialog(context, activeCase.id),
                                  ),
                                ],
                                child: exhibitsAsync.when(
                                  data: (exhibits) {
                                    if (exhibits.isEmpty) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          children: [
                                            Icon(Icons.file_present_rounded, size: 36, color: Colors.grey[500]),
                                            const SizedBox(height: 6),
                                            const Text('No documents or exhibits attached yet', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                DossierButton(
                                                  text: '+ Aadhaar Front',
                                                  icon: Icons.badge_rounded,
                                                  size: DossierButtonSize.sm,
                                                  variant: DossierButtonVariant.outline,
                                                  onPressed: () => _openAttachDialog(context, activeCase.id, 'Aadhaar Front'),
                                                ),
                                                DossierButton(
                                                  text: '+ Aadhaar Back',
                                                  icon: Icons.badge_outlined,
                                                  size: DossierButtonSize.sm,
                                                  variant: DossierButtonVariant.outline,
                                                  onPressed: () => _openAttachDialog(context, activeCase.id, 'Aadhaar Back'),
                                                ),
                                                DossierButton(
                                                  text: '+ Passport Photo',
                                                  icon: Icons.photo_camera_front_rounded,
                                                  size: DossierButtonSize.sm,
                                                  variant: DossierButtonVariant.outline,
                                                  onPressed: () => _openAttachDialog(context, activeCase.id, 'Passport Photo'),
                                                ),
                                                DossierButton(
                                                  text: '+ Signature',
                                                  icon: Icons.draw_rounded,
                                                  size: DossierButtonSize.sm,
                                                  variant: DossierButtonVariant.outline,
                                                  onPressed: () => _openAttachDialog(context, activeCase.id, 'Signature'),
                                                ),
                                                DossierButton(
                                                  text: '+ Browse Any File',
                                                  icon: Icons.upload_file_rounded,
                                                  size: DossierButtonSize.sm,
                                                  variant: DossierButtonVariant.secondary,
                                                  onPressed: () => _openAttachDialog(context, activeCase.id),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: exhibits.length,
                                      separatorBuilder: (context, _) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final ex = exhibits[index];
                                        final isImage = ex.mimeType.startsWith('image/');
                                        final isPdf = ex.mimeType.contains('pdf') || ex.fileName.toLowerCase().endsWith('.pdf');
                                        final hasLocal = ex.localPath != null && ex.localPath!.isNotEmpty && File(ex.localPath!).existsSync();

                                        return InkWell(
                                          onTap: () => _openExhibitPreview(context, ex),
                                          borderRadius: BorderRadius.circular(10),
                                          child: DossierCard(
                                            variant: DossierCardVariant.flat,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            borderRadius: 10,
                                            child: Row(
                                              children: [
                                                if (isImage && hasLocal)
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.file(
                                                      File(ex.localPath!),
                                                      width: 38,
                                                      height: 38,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: (isPdf ? Colors.redAccent : const Color(0xFF6366F1)).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                                                      color: isPdf ? Colors.redAccent : const Color(0xFF6366F1),
                                                      size: 20,
                                                    ),
                                                  ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        ex.fileName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${ex.slotType} • ${(ex.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DossierBadge(
                                                  label: ex.slotType,
                                                  variant: DossierBadgeVariant.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                                  tooltip: 'Preview Document',
                                                  onPressed: () => _openExhibitPreview(context, ex),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (err, _) => Text('Error loading exhibits: $err'),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Notes & Remarks Panel
                              DossierPanel(
                                title: 'Customer Remarks & Instructions',
                                subtitle: 'Special notes for operator shifts and token follow-ups',
                                leading: const Icon(Icons.sticky_note_2_rounded, size: 18, color: Color(0xFFF59E0B)),
                                isCollapsible: true,
                                initiallyExpanded: (activeDossier.notes ?? '').isNotEmpty,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      DossierInputField(
                                        initialValue: activeDossier.notes ?? '',
                                        hintText: 'Enter operator remarks, portal application token, or document requirements...',
                                        maxLines: 3,
                                        onChanged: (val) {
                                          ref.read(databaseProvider).updateDossierNotes(activeDossier.id, val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Danger Zone / Delete Case
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                  label: const Text('Delete This Case', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  onPressed: () => _confirmDeleteCase(context, ref, activeCase),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading cases: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
