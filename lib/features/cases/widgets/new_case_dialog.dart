import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
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

    return Dialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: servicesAsync.when(
          data: (services) {
            // Filter by active categories opt-in
            final filteredServices = services
                .where((s) => !s.isArchived && settings.activeCategories.contains(s.category))
                .toList();
            return _buildContent(filteredServices, settings);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading services: $err')),
        ),
      ),
    );
  }

  Widget _buildContent(List<Service> services, KioskSettings settings) {
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.post_add_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start New Job / Case Intake',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Customer: ${widget.customer.fullName} (${widget.customer.phoneNumber})',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Case Title / Job Description',
            hintText: 'e.g. Fresh PAN Card Application + 2 Xerox',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Services (Check all that apply):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: services.isEmpty
              ? const Center(child: Text('No active services in selected categories. Check Settings to enable categories.'))
              : ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    final isSelected = _selectedServiceIds.contains(s.id);
                    final qty = _serviceQuantities[s.id] ?? 1;

                    return InkWell(
                      onTap: () => _toggleService(s),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Portal: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)} | Shop: ${settings.currencySymbol}${s.defaultServiceFee.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                                onPressed: () {
                                  if (qty > 1) {
                                    setState(() => _serviceQuantities[s.id] = qty - 1);
                                  }
                                },
                              ),
                              Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() => _serviceQuantities[s.id] = qty + 1);
                                },
                              ),
                            ],
                            Text(
                              '${settings.currencySymbol}${((s.defaultPortalFee + s.defaultServiceFee) * qty).toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),

        // Live Margin & Checklist summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pass-through Cost: ${settings.currencySymbol}${totalPortal.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  Text('Kiosk Profit: ${settings.currencySymbol}${totalService.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Total Estimate: ${settings.currencySymbol}${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              if (requiredDocsUnion.isNotEmpty) ...[
                Divider(height: 16, color: Theme.of(context).dividerColor),
                Text(
                  'Auto-Merged Document Checklist: ${requiredDocsUnion.join(" • ")}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _advanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Advance Collected (${settings.currencySymbol})',
                  hintText: 'e.g. 100',
                  prefixText: '${settings.currencySymbol} ',
                ),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _handleCreateCase(services),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Create Case & Print Token'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
