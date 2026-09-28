import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/domain/services/upi_qr_service.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/features/billing_pos/widgets/quick_tender_pad.dart';
import 'package:dossier/presentation/widgets/animated_thermal_receipt.dart';
import 'package:dossier/presentation/common_widgets/dossier_resizable_split_view.dart';

class QuickPosScreen extends ConsumerStatefulWidget {
  const QuickPosScreen({super.key});

  @override
  ConsumerState<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _QuickPosScreenState extends ConsumerState<QuickPosScreen> {
  final Map<String, int> _cart = {}; // serviceId -> qty
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  static const _categories = [
    {'key': 'ALL', 'label': 'All Services', 'icon': Icons.apps_rounded},
    {'key': 'PRINTING', 'label': 'Printing & Xerox', 'icon': Icons.print_rounded},
    {'key': 'GOVT_SCHEME', 'label': 'Govt Schemes', 'icon': Icons.account_balance_rounded},
    {'key': 'CERTIFICATE', 'label': 'Certificates', 'icon': Icons.verified_rounded},
    {'key': 'UTILITY', 'label': 'Utility Bills', 'icon': Icons.receipt_long_rounded},
    {'key': 'LEGAL', 'label': 'Legal & Typing', 'icon': Icons.description_rounded},
    {'key': 'FINANCIAL', 'label': 'Financial', 'icon': Icons.account_balance_wallet_rounded},
  ];

  void _addItem(String id) {
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
  }

  void _removeItem(String id) {
    setState(() {
      if ((_cart[id] ?? 0) > 1) {
        _cart[id] = _cart[id]! - 1;
      } else {
        _cart.remove(id);
      }
    });
  }

  double _calculateSubtotal(List<Service> services) {
    double sum = 0;
    _cart.forEach((id, qty) {
      final service = services.where((s) => s.id == id).firstOrNull;
      if (service != null) {
        sum += (service.defaultPortalFee + service.defaultServiceFee) * qty;
      }
    });
    return sum;
  }

  void _openCashTenderModal({
    required BuildContext context,
    required double totalAmount,
    required List<Service> services,
    required KioskSettings settings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: QuickTenderPad(
              totalAmount: totalAmount,
              onCompletePayment: (tendered, change) {
                Navigator.of(dialogCtx).pop();
                _completeCheckout(
                  paymentMode: 'CASH',
                  totalAmount: totalAmount,
                  tenderedAmount: tendered,
                  changeAmount: change,
                  services: services,
                  settings: settings,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _completeCheckout({
    required String paymentMode,
    required double totalAmount,
    double? tenderedAmount,
    double? changeAmount,
    required List<Service> services,
    required KioskSettings settings,
  }) async {
    if (_cart.isEmpty) return;

    try {
      final db = ref.read(databaseProvider);
      const uuid = Uuid();
      final invoiceId = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final cartItems = _cart.entries.map((entry) {
        final s = services.where((item) => item.id == entry.key).firstOrNull;
        final title = s?.name ?? 'Counter Service';
        final unitPrice = s != null ? (s.defaultPortalFee + s.defaultServiceFee) : 0.0;
        return ReceiptLineItem(
          title: title,
          qty: entry.value,
          unitPrice: unitPrice,
          total: unitPrice * entry.value,
        );
      }).toList();

      await db.insertInvoice(
        InvoicesCompanion.insert(
          id: uuid.v4(),
          invoiceNumber: invoiceId,
          invoiceType: 'WALK_IN_POS',
          subtotal: totalAmount,
          grandTotal: totalAmount,
          amountPaid: drift.Value(totalAmount),
          paymentStatus: const drift.Value('PAID'),
        ),
      );

      if (!mounted) return;
      setState(() => _cart.clear());

      AnimatedThermalReceiptDialog.show(
        context,
        invoiceNumber: invoiceId,
        paymentMode: paymentMode,
        subtotal: totalAmount,
        grandTotal: totalAmount,
        amountTendered: tenderedAmount,
        changeDue: changeAmount,
        items: cartItems,
        settings: settings,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sale: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final servicesAsync = ref.watch(activeServicesStreamProvider);
    final allServices = servicesAsync.value ?? [];

    final filteredServices = allServices.where((s) {
      final matchesCategory = _selectedCategory == 'ALL' || s.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || s.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final subtotal = _calculateSubtotal(allServices);
    final upiPayload = UpiQrService.generateUpiPayload(
      merchantVpa: settings.merchantUpiVpa,
      merchantName: settings.kioskName,
      amount: subtotal > 0 ? subtotal : 1.0,
      transactionId: 'POS-${DateTime.now().millisecondsSinceEpoch % 100000}',
      note: 'Walk-in Counter POS',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (!isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildCategoryBar(),
                  const SizedBox(height: 14),
                  _buildProductGrid(filteredServices, settings, servicesAsync.isLoading && allServices.isEmpty),
                  const SizedBox(height: 20),
                  _buildCartSection(context, settings, subtotal, upiPayload, allServices),
                ],
              ),
            );
          }

          return DossierResizableSplitView(
            direction: Axis.horizontal,
            responsiveBreakpoint: 900.0,
            panes: [
              ResizablePane(
                id: 'pos_catalog',
                isFlexible: true,
                minSize: 360.0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildCategoryBar(),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildProductGrid(filteredServices, settings, servicesAsync.isLoading && allServices.isEmpty),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ResizablePane(
                id: 'pos_cart',
                initialSize: 360.0,
                minSize: 300.0,
                maxSize: 520.0,
                child: Container(
                  color: Theme.of(context).cardTheme.color,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: _buildCartSection(context, settings, subtotal, upiPayload, allServices),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Walk-in POS Counter',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DossierBadge(label: '${_cart.length} ITEMS', variant: DossierBadgeVariant.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '1-Tap quick billing directly linked to your catalog',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DossierInputField(
                isSearch: true,
                hintText: 'Search service...',
                showClearButton: true,
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ],
          );
        }

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Walk-in POS Counter',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DossierBadge(label: '${_cart.length} ITEMS', variant: DossierBadgeVariant.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '1-Tap quick billing directly linked to your configured services catalog',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DossierInputField(
                isSearch: true,
                hintText: 'Search service...',
                showClearButton: true,
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(cat['icon'] as IconData, size: 14, color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary),
              label: Text(cat['label'] as String, style: const TextStyle(fontSize: 11.5)),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : null,
              ),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _selectedCategory = cat['key'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductGrid(List<Service> services, KioskSettings settings, [bool isLoading = false]) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[500]),
              const SizedBox(height: 8),
              const Text('No services match the filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Adjust search or check active categories in Settings', style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final s = services[index];
        final price = s.defaultPortalFee + s.defaultServiceFee;
        final inCart = _cart[s.id] ?? 0;

        return DossierCard(
          onTap: () => _addItem(s.id),
          isSelected: inCart > 0,
          variant: inCart > 0 ? DossierCardVariant.glass : DossierCardVariant.flat,
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
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (inCart > 0)
                    DossierBadge(
                      label: '$inCart',
                      variant: DossierBadgeVariant.primary,
                      fontSize: 10,
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${settings.currencySymbol}${price.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Govt: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartSection(
    BuildContext context,
    KioskSettings settings,
    double subtotal,
    String upiPayload,
    List<Service> services,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Current Cart', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (_cart.isNotEmpty)
              DossierButton(
                text: 'Clear',
                size: DossierButtonSize.sm,
                variant: DossierButtonVariant.ghost,
                customColor: Colors.redAccent,
                onPressed: () => setState(() => _cart.clear()),
              ),
          ],
        ),
        Divider(color: Theme.of(context).dividerColor),

        if (_cart.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey[500]),
                  const SizedBox(height: 6),
                  Text('Cart is empty', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('Tap any counter service to add', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cart.length,
            separatorBuilder: (context, _) => Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.5), height: 1),
            itemBuilder: (context, index) {
              final id = _cart.keys.elementAt(index);
              final qty = _cart[id]!;
              final service = services.where((s) => s.id == id).firstOrNull;
              final title = service?.name ?? 'Custom Item';
              final unitPrice = service != null ? (service.defaultPortalFee + service.defaultServiceFee) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${settings.currencySymbol}$unitPrice x $qty', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeItem(id),
                    ),
                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.grey),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addItem(id),
                    ),
                    const SizedBox(width: 4),
                    Text('${settings.currencySymbol}${(unitPrice * qty).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 12),

        // Total & Dynamic QR Card
        DossierCard(
          variant: DossierCardVariant.glass,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '${settings.currencySymbol}${subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 18),
                  ),
                ],
              ),
              if (subtotal > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: QrImageView(data: upiPayload, size: 90, version: QrVersions.auto),
                ),
                const SizedBox(height: 4),
                Text('Instant UPI: ${settings.merchantUpiVpa}',
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Checkout Buttons
        Row(
          children: [
            Expanded(
              child: DossierButton(
                text: 'Cash Tender',
                icon: Icons.payments_rounded,
                variant: DossierButtonVariant.outline,
                customColor: const Color(0xFF10B981),
                size: DossierButtonSize.md,
                tooltip: 'Open Quick Touch Numpad & Return Change Calculator',
                onPressed: subtotal == 0
                    ? null
                    : () => _openCashTenderModal(
                          context: context,
                          totalAmount: subtotal,
                          services: services,
                          settings: settings,
                        ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DossierButton(
                text: 'UPI & Slip',
                icon: Icons.receipt_long_rounded,
                variant: DossierButtonVariant.primary,
                size: DossierButtonSize.md,
                onPressed: subtotal == 0
                    ? null
                    : () => _completeCheckout(
                          paymentMode: 'UPI_QR',
                          totalAmount: subtotal,
                          services: services,
                          settings: settings,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
