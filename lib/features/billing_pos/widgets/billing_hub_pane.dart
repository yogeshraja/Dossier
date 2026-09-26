import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/domain/services/upi_qr_service.dart';
import 'package:dossier/domain/services/whatsapp_notification_service.dart';

class BillingHubPane extends ConsumerWidget {
  const BillingHubPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDossier = ref.watch(activeDossierProvider);
    final activeCase = ref.watch(activeCaseProvider);

    if (activeCase == null || activeDossier == null) {
      return Container(
        width: 340,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(left: BorderSide(color: Color(0xFF334155), width: 1)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale_rounded, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 12),
                const Text('Billing & Comms Hub', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Select an active case to generate dynamic UPI QR, thermal slip, and WhatsApp alerts',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final balanceDue = (activeCase.totalEstimatedAmount - activeCase.advancePaid).clamp(0.0, 99999.0);
    final upiPayload = UpiQrService.generateUpiPayload(
      merchantVpa: 'csckiosk@oksbi',
      merchantName: 'Dossier Kiosk Station',
      amount: balanceDue > 0 ? balanceDue : activeCase.totalEstimatedAmount,
      transactionId: 'TXN-${activeCase.id.substring(0, 8).toUpperCase()}',
      note: 'Dossier ${activeCase.title}',
    );

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(left: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF34D399), size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Billing & Quick Dispatch', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic UPI QR Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Dynamic UPI QR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                balanceDue > 0 ? '₹${balanceDue.toStringAsFixed(0)} Due' : 'Paid',
                                style: TextStyle(
                                  color: balanceDue > 0 ? const Color(0xFFF59E0B) : const Color(0xFF34D399),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: upiPayload,
                            version: QrVersions.auto,
                            size: 160.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan with GPay, PhonePe, Paytm',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'UPI ID: csckiosk@oksbi',
                          style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WhatsApp Notifications
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                            SizedBox(width: 8),
                            Text('1-Tap WhatsApp Alerts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () {
                            WhatsAppNotificationService.sendReadyForPickupAlert(
                              phoneNumber: activeDossier.phoneNumber,
                              customerName: activeDossier.fullName,
                              caseTitle: activeCase.title,
                              balanceDue: balanceDue,
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('Send Ready for Pickup'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () {
                            WhatsAppNotificationService.sendMissingDocumentAlert(
                              phoneNumber: activeDossier.phoneNumber,
                              customerName: activeDossier.fullName,
                              caseTitle: activeCase.title,
                              missingDocs: ['Original Aadhaar Card', 'Passport Sized Photograph'],
                            );
                          },
                          icon: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amberAccent),
                          label: const Text('Request Missing Docs', style: TextStyle(color: Colors.amberAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amberAccent),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thermal Slip Preview
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFBF7), // Thermal receipt paper color
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            '=== DOSSIER KIOSK ===\nMain Market CSC Center\nPhone: +91 98765 43210',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
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
                            Text('₹${activeCase.totalEstimatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Advance Paid:', style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                            Text('₹${activeCase.advancePaid.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('BALANCE DUE:', style: TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('₹${balanceDue.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ESC/POS byte stream sent to 58mm Thermal Receipt Printer!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 14),
                          label: const Text('Print 58mm Receipt Slip'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
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
}
