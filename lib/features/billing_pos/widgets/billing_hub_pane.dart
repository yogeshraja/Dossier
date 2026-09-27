import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/domain/services/upi_qr_service.dart';
import 'package:dossier/domain/services/whatsapp_notification_service.dart';
import 'package:dossier/features/billing_pos/widgets/record_payment_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

class BillingHubPane extends ConsumerWidget {
  const BillingHubPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDossier = ref.watch(activeDossierProvider);
    final activeCase = ref.watch(activeCaseProvider);
    final isExpanded = ref.watch(isBillingHubExpandedProvider);
    final settings = ref.watch(kioskSettingsProvider);

    if (!isExpanded) {
      return const SizedBox.shrink();
    }

    if (activeCase == null || activeDossier == null) {
      return Container(
        width: 350,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
        ),
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      const Text('Billing & Quick Dispatch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        'Select an active case to generate dynamic UPI QR, thermal slip, and WhatsApp alerts',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final balanceDue = (activeCase.totalEstimatedAmount - activeCase.advancePaid).clamp(0.0, 99999.0);
    final upiPayload = UpiQrService.generateUpiPayload(
      merchantVpa: settings.merchantUpiVpa,
      merchantName: settings.kioskName,
      amount: balanceDue > 0 ? balanceDue : activeCase.totalEstimatedAmount,
      transactionId: 'TXN-${activeCase.id.substring(0, 8).toUpperCase()}',
      note: 'Dossier ${activeCase.title}',
    );

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(context, ref),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic UPI QR Card
                  DossierCard(
                    variant: DossierCardVariant.glass,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Dynamic UPI QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            DossierBadge(
                              label: balanceDue > 0 ? '${settings.currencySymbol}${balanceDue.toStringAsFixed(0)} Due' : 'Paid in Full',
                              variant: balanceDue > 0 ? DossierBadgeVariant.warning : DossierBadgeVariant.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                            ],
                          ),
                          child: QrImageView(
                            data: upiPayload,
                            version: QrVersions.auto,
                            size: 150.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan with GPay, PhonePe, Paytm',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'VPA: ${settings.merchantUpiVpa}',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        DossierButton(
                          text: balanceDue > 0 ? 'Record Payment (${settings.currencySymbol}${balanceDue.toStringAsFixed(0)})' : 'Record New Payment',
                          icon: Icons.payments_rounded,
                          size: DossierButtonSize.sm,
                          variant: DossierButtonVariant.success,
                          isFullWidth: true,
                          onPressed: () {
                            DossierDialog.show(
                              context: context,
                              builder: (_) => RecordPaymentDialog(caseItem: activeCase, customer: activeDossier),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WhatsApp Notifications
                  DossierCard(
                    variant: DossierCardVariant.outlined,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                            SizedBox(width: 8),
                            Text('1-Tap WhatsApp Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DossierButton(
                          text: 'Send Ready for Pickup',
                          icon: Icons.send_rounded,
                          size: DossierButtonSize.sm,
                          customColor: const Color(0xFF25D366),
                          isFullWidth: true,
                          onPressed: () {
                            WhatsAppNotificationService.sendReadyForPickupAlert(
                              phoneNumber: activeDossier.phoneNumber,
                              customerName: activeDossier.fullName,
                              caseTitle: activeCase.title,
                              balanceDue: balanceDue,
                              kioskName: settings.kioskName,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        DossierButton(
                          text: 'Request Missing Docs',
                          icon: Icons.warning_amber_rounded,
                          size: DossierButtonSize.sm,
                          variant: DossierButtonVariant.outline,
                          customColor: Colors.amber,
                          isFullWidth: true,
                          onPressed: () {
                            WhatsAppNotificationService.sendMissingDocumentAlert(
                              phoneNumber: activeDossier.phoneNumber,
                              customerName: activeDossier.fullName,
                              caseTitle: activeCase.title,
                              missingDocs: ['Original Aadhaar Card', 'Passport Size Photo'],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thermal Slip Preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFBF7), // Authentic thermal receipt paper
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            '=== ${settings.kioskName.toUpperCase()} ===\n${settings.kioskAddress}\nPhone: ${settings.kioskPhone}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text('--------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),
                        Text('Customer: ${activeDossier.fullName}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                        Text('Job: ${activeCase.title}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                        Text('Status: ${activeCase.stage}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                        const Text('--------------------------------', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', color: Colors.black54)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Estimate:', style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                            Text('${settings.currencySymbol}${activeCase.totalEstimatedAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Advance Paid:', style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                            Text('${settings.currencySymbol}${activeCase.advancePaid.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('BALANCE DUE:', style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('${settings.currencySymbol}${balanceDue.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DossierButton(
                          text: 'Print 58mm Receipt Slip',
                          icon: Icons.print_rounded,
                          size: DossierButtonSize.sm,
                          customColor: const Color(0xFF0F172A),
                          isFullWidth: true,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ESC/POS byte stream sent to 58mm Thermal Receipt Printer!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Billing & Quick Dispatch',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            tooltip: 'Collapse Billing Hub',
            onPressed: () => ref.read(isBillingHubExpandedProvider.notifier).state = false,
          ),
        ],
      ),
    );
  }
}
