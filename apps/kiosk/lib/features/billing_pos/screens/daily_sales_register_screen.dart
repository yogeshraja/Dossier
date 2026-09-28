import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/billing_pos/providers/sales_report_provider.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_panel.dart';
import 'package:dossier/presentation/widgets/sparkline_chart.dart';
import 'package:dossier/presentation/widgets/animated_thermal_receipt.dart';

class DailySalesRegisterScreen extends ConsumerStatefulWidget {
  const DailySalesRegisterScreen({super.key});

  @override
  ConsumerState<DailySalesRegisterScreen> createState() => _DailySalesRegisterScreenState();
}

class _DailySalesRegisterScreenState extends ConsumerState<DailySalesRegisterScreen> {
  final TextEditingController _floatController = TextEditingController(text: '500');
  final TextEditingController _countedController = TextEditingController(text: '500');

  @override
  void dispose() {
    _floatController.dispose();
    _countedController.dispose();
    super.dispose();
  }

  void _showEodSlipDialog(SalesReportSummary summary, SalesReportState reportState) {
    final settings = ref.read(kioskSettingsProvider);
    final auth = ref.read(authProvider);

    final opening = double.tryParse(_floatController.text) ?? reportState.openingCashFloat;
    final physical = double.tryParse(_countedController.text) ?? reportState.physicalCountedCash;

    final eodItems = summary.serviceCountBreakdown.entries
        .map((e) => ReceiptLineItem(
              title: e.key,
              qty: e.value,
              unitPrice: 0.0,
              total: 0.0,
            ))
        .toList();

    AnimatedThermalReceiptDialog.show(
      context,
      invoiceNumber: 'EOD-${DateTime.now().millisecondsSinceEpoch % 100000}',
      paymentMode: 'EOD REGISTER RECONCILIATION',
      subtotal: summary.totalGrossSales,
      grandTotal: summary.totalGrossSales,
      amountTendered: physical,
      changeDue: physical > (opening + summary.totalCashCollected) ? physical - (opening + summary.totalCashCollected) : null,
      items: eodItems.isNotEmpty
          ? eodItems
          : [
              ReceiptLineItem(
                title: 'Total Register Transactions',
                qty: summary.totalOrders,
                unitPrice: summary.totalGrossSales,
                total: summary.totalGrossSales,
              )
            ],
      customerName: 'Operator: ${auth.currentOperator?.fullName ?? "Kiosk Admin"}',
      settings: settings,
    );
  }

  List<SparklinePoint> _generateHourlyPoints(List<Invoice> invoices) {
    int minHour = 8;
    int maxHour = 20;

    for (final inv in invoices) {
      final h = inv.createdAt.hour;
      if (h < minHour) minHour = h;
      if (h > maxHour) maxHour = h;
    }

    final Map<int, (double total, int count)> hourlyMap = {};
    for (int h = minHour; h <= maxHour; h++) {
      hourlyMap[h] = (0.0, 0);
    }

    for (final inv in invoices) {
      final h = inv.createdAt.hour;
      final current = hourlyMap[h] ?? (0.0, 0);
      hourlyMap[h] = (current.$1 + inv.grandTotal, current.$2 + 1);
    }

    final sortedKeys = hourlyMap.keys.toList()..sort();
    return sortedKeys.map((h) {
      final val = hourlyMap[h]!;
      final hourLabel = '${h.toString().padLeft(2, '0')}:00';
      return SparklinePoint(
        label: hourLabel,
        value: val.$1,
        count: val.$2,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportState = ref.watch(salesReportProvider);
    final summaryAsync = ref.watch(salesReportSummaryProvider);
    final settings = ref.watch(kioskSettingsProvider);
    final sym = settings.currencySymbol;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Daily Sales & Cash Register',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'End-of-day counter reconciliation, cash drawer audits, and thermal slips',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Date Range Segmented Pills
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: SalesReportDateRange.values.map((range) {
                              final isSelected = reportState.dateRange == range;
                              return GestureDetector(
                                onTap: () => ref.read(salesReportProvider.notifier).setDateRange(range),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    range.label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        summaryAsync.when(
                          data: (summary) => DossierButton(
                            text: 'Print EOD Slip',
                            icon: Icons.print_rounded,
                            variant: DossierButtonVariant.primary,
                            size: DossierButtonSize.sm,
                            tooltip: 'Generate and print ESC/POS thermal register closure receipt',
                            onPressed: () => _showEodSlipDialog(summary, reportState),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Summary Metrics Cards
            summaryAsync.when(
              data: (summary) {
                final hourlyPoints = _generateHourlyPoints(summary.invoices);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 750;
                        return GridView.count(
                          crossAxisCount: isNarrow ? 2 : 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isNarrow ? 1.2 : 2.0,
                          children: [
                            _buildMetricCard('Total Revenue', '$sym${summary.totalGrossSales.toStringAsFixed(2)}', Icons.monetization_on_rounded, const Color(0xFF10B981), '${summary.totalOrders} Orders'),
                            _buildMetricCard('Cash in Drawer', '$sym${summary.totalCashCollected.toStringAsFixed(2)}', Icons.payments_rounded, const Color(0xFF3B82F6), 'Cash inflow'),
                            _buildMetricCard('UPI / Online', '$sym${summary.totalUpiCollected.toStringAsFixed(2)}', Icons.qr_code_2_rounded, const Color(0xFF8B5CF6), 'Digital payments'),
                            _buildMetricCard('Pending Dues', '$sym${summary.totalPendingDues.toStringAsFixed(2)}', Icons.warning_amber_rounded, const Color(0xFFF59E0B), 'Outstanding balance'),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Interactive Sparkline Micro-Chart Card
                    DossierCard(
                      variant: DossierCardVariant.glass,
                      padding: const EdgeInsets.all(16),
                      child: SparklineChart(
                        points: hourlyPoints,
                        height: 110,
                        currencySymbol: sym,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Cash Drawer Reconciliation & Volume Breakdown
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 850;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildDrawerReconciliationCard(summary, sym, isDark)),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildVolumeBreakdownCard(summary, isDark)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildDrawerReconciliationCard(summary, sym, isDark),
                              const SizedBox(height: 16),
                              _buildVolumeBreakdownCard(summary, isDark),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Invoices Ledger Table
                    DossierPanel(
                      title: 'Transactions & Invoices (${summary.invoices.length})',
                      subtitle: 'Itemized ledger for the selected period',
                      leading: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF6366F1)),
                      isCollapsible: true,
                      initiallyExpanded: true,
                      child: summary.invoices.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('No transactions recorded for this period', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summary.invoices.length,
                              separatorBuilder: (context, _) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              itemBuilder: (context, index) {
                                final inv = summary.invoices[index];
                                final isPaid = inv.paymentStatus.toUpperCase() == 'PAID';
                                final title = inv.invoiceType == 'WALK_IN_POS' ? 'Quick POS Sale' : 'Case Service Fee';
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    child: Icon(isPaid ? Icons.check_circle_outline : Icons.pending_actions_outlined, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 15),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    '${inv.invoiceNumber} • ${inv.createdAt.hour.toString().padLeft(2, '0')}:${inv.createdAt.minute.toString().padLeft(2, '0')} • ${inv.paymentStatus}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$sym${inv.grandTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                      if (inv.grandTotal > inv.amountPaid)
                                        Text(
                                          'Due: $sym${(inv.grandTotal - inv.amountPaid).toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(child: Text('Error loading sales ledger: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String sub) {
    return DossierCard(
      variant: DossierCardVariant.glass,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _buildDrawerReconciliationCard(SalesReportSummary summary, String sym, bool isDark) {
    final opening = double.tryParse(_floatController.text) ?? 500.0;
    final physical = double.tryParse(_countedController.text) ?? 500.0;
    final expected = opening + summary.totalCashCollected;
    final variance = physical - expected;

    return DossierCard(
      variant: DossierCardVariant.glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: const Text(
                      'Cash Drawer Audit & Float',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              DossierBadge(
                label: variance == 0 ? 'BALANCED' : (variance > 0 ? 'OVERAGE (+$sym${variance.toStringAsFixed(2)})' : 'SHORTAGE (-$sym${variance.abs().toStringAsFixed(2)})'),
                variant: variance == 0 ? DossierBadgeVariant.success : (variance > 0 ? DossierBadgeVariant.primary : DossierBadgeVariant.warning),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _floatController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Opening Float ($sym)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _countedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Physical Cash ($sym)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildStatItem('Opening Float', '$sym${opening.toStringAsFixed(2)}'),
                _buildStatItem('+ Inflow', '$sym${summary.totalCashCollected.toStringAsFixed(2)}'),
                _buildStatItem('Expected In Drawer', '$sym${expected.toStringAsFixed(2)}', isBold: true),
                _buildStatItem('Counted Cash', '$sym${physical.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool isBold = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildVolumeBreakdownCard(SalesReportSummary summary, bool isDark) {
    return DossierCard(
      variant: DossierCardVariant.glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text('Service Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.serviceCountBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(child: Text('No services rendered', style: TextStyle(color: Colors.grey[500], fontSize: 12))),
            )
          else
            ...summary.serviceCountBreakdown.entries.map((entry) {
              final pct = summary.totalOrders > 0 ? (entry.value / summary.totalOrders) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Text('${entry.value} (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 4,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
