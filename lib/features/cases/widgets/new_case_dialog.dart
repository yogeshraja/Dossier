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
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:uuid/uuid.dart';

class NewCaseDialog extends ConsumerStatefulWidget {
  final Dossier customer;
  const NewCaseDialog({super.key, required this.customer});

  @override
  ConsumerState<NewCaseDialog> createState() => _NewCaseDialogState();
}

class _NewCaseDialogState extends ConsumerState<NewCaseDialog> {
  final _titleController = TextEditingController();
  final _advanceController = TextEditingController(text: '0');
  final Set<String> _selectedServiceIds = {};
  final Map<String, int> _serviceQuantities = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  void _toggleService(Service service) {
    setState(() {
      if (_selectedServiceIds.contains(service.id)) {
        _selectedServiceIds.remove(service.id);
        _serviceQuantities.remove(service.id);
      } else {
        _selectedServiceIds.add(service.id);
        _serviceQuantities[service.id] = 1;
        if (_titleController.text.isEmpty) {
          _titleController.text = service.name;
        }
      }
    });
  }

  Future<void> _handleCreateCase(List<Service> allServices) async {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service to create a case!')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      const uuid = Uuid();
      final caseId = uuid.v4();

      double totalPortal = 0;
      double totalService = 0;

      final selectedServices = allServices.where((s) => _selectedServiceIds.contains(s.id)).toList();
      for (final s in selectedServices) {
        final qty = _serviceQuantities[s.id] ?? 1;
        totalPortal += s.defaultPortalFee * qty;
        totalService += s.defaultServiceFee * qty;
      }

      final grandTotal = totalPortal + totalService;
      final advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;
      final paymentStatus = advance >= grandTotal
          ? 'PAID'
          : advance > 0
              ? 'PARTIALLY_PAID'
              : 'UNPAID';

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : selectedServices.map((s) => s.name).join(' + ');

      // Insert case & line items in a transaction
      await db.transaction(() async {
        await db.insertCase(
          CasesCompanion.insert(
            id: caseId,
            dossierId: widget.customer.id,
            title: title,
            stage: const drift.Value('DOCS_PENDING'),
            totalPortalFee: drift.Value(totalPortal),
            totalServiceFee: drift.Value(totalService),
            totalEstimatedAmount: drift.Value(grandTotal),
            advancePaid: drift.Value(advance),
            paymentStatus: drift.Value(paymentStatus),
          ),
        );

        for (final s in selectedServices) {
          final qty = _serviceQuantities[s.id] ?? 1;
          await db.into(db.caseServices).insert(
            CaseServicesCompanion.insert(
              id: uuid.v4(),
              caseId: caseId,
              serviceId: s.id,
              appliedPortalFee: s.defaultPortalFee,
              appliedServiceFee: s.defaultServiceFee,
              quantity: drift.Value(qty),
            ),
          );
        }

        // If advance > 0, generate receipt/invoice automatically
        if (advance > 0) {
          final invoiceId = uuid.v4();
          final invNumber = 'INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';
          await db.insertInvoice(
            InvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: invNumber,
              dossierId: drift.Value(widget.customer.id),
              caseId: drift.Value(caseId),
              invoiceType: 'CASE_INVOICE',
              subtotal: grandTotal,
              grandTotal: grandTotal,
              amountPaid: drift.Value(advance),
              paymentStatus: drift.Value(paymentStatus),
            ),
          );

          await db.insertLedgerEntry(
            LedgerEntriesCompanion.insert(
              id: uuid.v4(),
              invoiceId: invoiceId,
              amount: advance,
              paymentMode: 'UPI',
              transactionRef: const drift.Value('Advance Deposit'),
            ),
          );
        }
      });

      ref.read(activeCaseIdProvider.notifier).state = caseId;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Case "$title" created for ${widget.customer.fullName}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating case: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeServicesStreamProvider);
    final settings = ref.watch(kioskSettingsProvider);

    return DossierDialog(
      title: 'Start New Job / Case Intake',
      subtitle: 'Customer: ${widget.customer.fullName} (${widget.customer.phoneNumber})',
      icon: Icons.post_add_rounded,
      maxWidth: 680,
      content: servicesAsync.when(
        data: (services) {
          final filteredServices = services
              .where((s) => !s.isArchived && settings.activeCategories.contains(s.category))
              .toList();
          return _buildFormContent(filteredServices, settings);
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Center(child: Text('Error loading services: $err')),
      ),
    );
  }

  Widget _buildFormContent(List<Service> services, KioskSettings settings) {
    double totalPortal = 0;
    double totalService = 0;
    final Set<String> requiredDocsUnion = {};

    for (final s in services.where((s) => _selectedServiceIds.contains(s.id))) {
      final qty = _serviceQuantities[s.id] ?? 1;
      totalPortal += s.defaultPortalFee * qty;
      totalService += s.defaultServiceFee * qty;
      try {
        final List<dynamic> docs = jsonDecode(s.requiredDocsJson);
        for (final d in docs) {
          requiredDocsUnion.add(d.toString());
        }
      } catch (_) {}
    }

    final grandTotal = totalPortal + totalService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DossierInputField(
          controller: _titleController,
          label: 'Case Title / Job Description',
          hintText: 'e.g. Fresh PAN Card Application + 2 Xerox',
          prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
          showClearButton: true,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Services to Attach:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            DossierBadge(
              label: '${_selectedServiceIds.length} Selected',
              variant: _selectedServiceIds.isNotEmpty ? DossierBadgeVariant.primary : DossierBadgeVariant.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Services list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: services.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No active services found in enabled categories.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: services.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    final isSelected = _selectedServiceIds.contains(s.id);
                    final qty = _serviceQuantities[s.id] ?? 1;

                    return DossierCard(
                      onTap: () => _toggleService(s),
                      isSelected: isSelected,
                      variant: isSelected ? DossierCardVariant.glass : DossierCardVariant.flat,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      borderRadius: 10,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Portal: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)} | Shop: ${settings.currencySymbol}${s.defaultServiceFee.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                if (qty > 1) {
                                  setState(() => _serviceQuantities[s.id] = qty - 1);
                                }
                              },
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() => _serviceQuantities[s.id] = qty + 1);
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${settings.currencySymbol}${((s.defaultPortalFee + s.defaultServiceFee) * qty).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),

        // Live Margin & Checklist summary
        DossierCard(
          variant: DossierCardVariant.flat,
          padding: const EdgeInsets.all(12),
          borderRadius: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Portal Fee: ${settings.currencySymbol}${totalPortal.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  Text('Kiosk Profit: ${settings.currencySymbol}${totalService.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Total Estimate: ${settings.currencySymbol}${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (requiredDocsUnion.isNotEmpty) ...[
                const Divider(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Docs Required: ${requiredDocsUnion.join(" • ")}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF818CF8), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: DossierInputField(
                controller: _advanceController,
                keyboardType: TextInputType.number,
                label: 'Advance Deposit Collected',
                hintText: '0',
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      settings.currencySymbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: DossierButton(
                text: 'Create Case & Print Token',
                icon: Icons.check_circle_rounded,
                variant: DossierButtonVariant.primary,
                size: DossierButtonSize.lg,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : () => _handleCreateCase(services),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
