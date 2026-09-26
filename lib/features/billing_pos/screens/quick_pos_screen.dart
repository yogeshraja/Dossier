import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/domain/services/upi_qr_service.dart';

class QuickPosScreen extends ConsumerStatefulWidget {
  const QuickPosScreen({super.key});

  @override
  ConsumerState<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _QuickPosScreenState extends ConsumerState<QuickPosScreen> {
  final Map<String, int> _cart = {}; // itemName -> qty
  final Map<String, double> _priceMap = {
    'Xerox B&W (A4)': 3.0,
    'Color Print (A4)': 10.0,
    'A4 Document Lamination': 25.0,
    'Passport Photos (Set of 8)': 60.0,
    'Urgent Online Form Fill': 80.0,
    'ID Card PVC Printing': 50.0,
  };

  void _addItem(String name) {
    setState(() {
      _cart[name] = (_cart[name] ?? 0) + 1;
    });
  }

  void _removeItem(String name) {
    setState(() {
      if ((_cart[name] ?? 0) > 1) {
        _cart[name] = _cart[name]! - 1;
      } else {
        _cart.remove(name);
      }
    });
  }

  double get _subtotal {
    double sum = 0;
    _cart.forEach((name, qty) {
      sum += (_priceMap[name] ?? 0) * qty;
    });
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _subtotal;
    final upiPayload = UpiQrService.generateUpiPayload(
      merchantVpa: 'csckiosk@oksbi',
      merchantName: 'Dossier Quick POS',
      amount: subtotal > 0 ? subtotal : 1.0,
      transactionId: 'POS-${DateTime.now().millisecondsSinceEpoch % 100000}',
      note: 'Walk-in Counter POS',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Row(
        children: [
          // Left Quick Sale Product Grid
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: Color(0xFF818CF8)),
                      SizedBox(width: 10),
                      Text('Walk-in POS Counter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('1-Tap quick billing for high-frequency counter jobs (Xerox, Print, Lamination)', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  const SizedBox(height: 20),

                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: _priceMap.length,
                      itemBuilder: (context, index) {
                        final key = _priceMap.keys.elementAt(index);
                        final price = _priceMap[key]!;
                        final inCart = _cart[key] ?? 0;

                        return InkWell(
                          onTap: () => _addItem(key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: inCart > 0 ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: inCart > 0 ? const Color(0xFF818CF8) : const Color(0xFF334155),
                                width: inCart > 0 ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        key,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (inCart > 0)
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: const Color(0xFF6366F1),
                                        child: Text('$inCart', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 18)),
                                    const Icon(Icons.add_circle_rounded, color: Color(0xFF818CF8), size: 24),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFF334155)),

          // Right Cart & Checkout Pane
          SizedBox(
            width: 380,
            child: Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Register Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (_cart.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _cart.clear()),
                          child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155)),

                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                const Text('Cart is empty', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                            itemBuilder: (context, index) {
                              final item = _cart.keys.elementAt(index);
                              final qty = _cart[item]!;
                              final unitPrice = _priceMap[item] ?? 0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                                          Text('₹$unitPrice x $qty', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey),
                                      onPressed: () => _removeItem(item),
                                    ),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.grey),
                                      onPressed: () => _addItem(item),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('₹${(unitPrice * qty).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Total & Payment
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
                            const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontSize: 22)),
                          ],
                        ),
                        if (subtotal > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            child: QrImageView(data: upiPayload, size: 110, version: QrVersions.auto),
                          ),
                          const SizedBox(height: 6),
                          const Text('Instant UPI QR: csckiosk@oksbi', style: TextStyle(fontSize: 11, color: Color(0xFF818CF8))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: subtotal == 0
                              ? null
                              : () {
                                  setState(() => _cart.clear());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cash Payment Logged to Drawer!'), backgroundColor: Color(0xFF10B981)),
                                  );
                                },
                          icon: const Icon(Icons.payments_rounded, color: Color(0xFF34D399)),
                          label: const Text('Cash Paid'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF34D399)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: subtotal == 0
                              ? null
                              : () {
                                  setState(() => _cart.clear());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('UPI Payment Logged & Thermal Slip Printed!'), backgroundColor: Color(0xFF6366F1)),
                                  );
                                },
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('UPI & Print'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
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
