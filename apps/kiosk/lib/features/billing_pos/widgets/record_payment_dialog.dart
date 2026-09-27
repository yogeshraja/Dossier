import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final Case caseItem;
  final Dossier customer;

  const RecordPaymentDialog({
    super.key,
    required this.caseItem,
    required this.customer,
  });

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _amountCtrl = TextEditingController();
  String _paymentMode = 'CASH'; // CASH, UPI, CARD
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final remaining = (widget.caseItem.totalEstimatedAmount - widget.caseItem.advancePaid).clamp(0.0, 999999.0);
    _amountCtrl.text = remaining > 0 ? remaining.toStringAsFixed(0) : '0';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final newAdvancePaid = widget.caseItem.advancePaid + amount;
      await db.updateCasePayment(widget.caseItem.id, newAdvancePaid);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(0)} recorded successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final remaining = (widget.caseItem.totalEstimatedAmount - widget.caseItem.advancePaid).clamp(0.0, 999999.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 440,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Record Counter Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'Customer: ${widget.customer.fullName} • ${widget.caseItem.title}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Card
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCol('Total Cost', '${settings.currencySymbol}${widget.caseItem.totalEstimatedAmount.toStringAsFixed(0)}', Colors.grey[500]!),
                _buildSummaryCol('Paid So Far', '${settings.currencySymbol}${widget.caseItem.advancePaid.toStringAsFixed(0)}', const Color(0xFF10B981)),
                _buildSummaryCol('Remaining Due', '${settings.currencySymbol}${remaining.toStringAsFixed(0)}', Colors.amber),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment Amount Input
          DossierInputField(
            controller: _amountCtrl,
            label: 'Amount Collected (${settings.currencySymbol})',
            hintText: 'Enter amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
          ),
          const SizedBox(height: 10),

          // Quick Presets
          Wrap(
            spacing: 6,
            children: [
              ActionChip(
                label: Text('Full Due (${settings.currencySymbol}${remaining.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _amountCtrl.text = remaining.toStringAsFixed(0)),
              ),
              if (remaining > 50)
                ActionChip(
                  label: Text('${settings.currencySymbol}50', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _amountCtrl.text = '50'),
                ),
              if (remaining > 100)
                ActionChip(
                  label: Text('${settings.currencySymbol}100', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _amountCtrl.text = '100'),
                ),
              if (remaining > 500)
                ActionChip(
                  label: Text('${settings.currencySymbol}500', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _amountCtrl.text = '500'),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Mode Selector
          Text(
            'Payment Mode:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildModeOption('CASH', 'Cash', Icons.money_rounded),
              const SizedBox(width: 8),
              _buildModeOption('UPI', 'UPI QR', Icons.qr_code_2_rounded),
              const SizedBox(width: 8),
              _buildModeOption('CARD', 'Card / Pos', Icons.credit_card_rounded),
            ],
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DossierButton(
                text: 'Cancel',
                variant: DossierButtonVariant.outline,
                size: DossierButtonSize.sm,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              DossierButton(
                text: 'Confirm & Record',
                icon: Icons.check_circle_rounded,
                variant: DossierButtonVariant.success,
                size: DossierButtonSize.sm,
                isLoading: _isSaving,
                onPressed: _recordPayment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(String key, String label, IconData icon) {
    final isSelected = _paymentMode == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMode = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
