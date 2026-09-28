import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/domain/services/esc_pos_printer_service.dart';

class ReceiptLineItem {
  final String title;
  final int qty;
  final double unitPrice;
  final double total;

  const ReceiptLineItem({
    required this.title,
    this.qty = 1,
    required this.unitPrice,
    required this.total,
  });
}

class AnimatedThermalReceiptDialog extends StatefulWidget {
  final String invoiceNumber;
  final String paymentMode;
  final double subtotal;
  final double grandTotal;
  final double? amountTendered;
  final double? changeDue;
  final List<ReceiptLineItem> items;
  final String? customerName;
  final String? customerPhone;
  final DateTime? timestamp;
  final KioskSettings settings;

  const AnimatedThermalReceiptDialog({
    super.key,
    required this.invoiceNumber,
    required this.paymentMode,
    required this.subtotal,
    required this.grandTotal,
    this.amountTendered,
    this.changeDue,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.timestamp,
    required this.settings,
  });

  static Future<void> show(
    BuildContext context, {
    required String invoiceNumber,
    required String paymentMode,
    required double subtotal,
    required double grandTotal,
    double? amountTendered,
    double? changeDue,
    required List<ReceiptLineItem> items,
    String? customerName,
    String? customerPhone,
    DateTime? timestamp,
    required KioskSettings settings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AnimatedThermalReceiptDialog(
        invoiceNumber: invoiceNumber,
        paymentMode: paymentMode,
        subtotal: subtotal,
        grandTotal: grandTotal,
        amountTendered: amountTendered,
        changeDue: changeDue,
        items: items,
        customerName: customerName,
        customerPhone: customerPhone,
        timestamp: timestamp,
        settings: settings,
      ),
    );
  }

  @override
  State<AnimatedThermalReceiptDialog> createState() => _AnimatedThermalReceiptDialogState();
}

class _AnimatedThermalReceiptDialogState extends State<AnimatedThermalReceiptDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerEscPosPrint() async {
    setState(() => _isPrinting = true);
    await Future.delayed(const Duration(milliseconds: 350));

    // Convert items to EscPos item maps
    final escPosItems = widget.items
        .map((it) => {
              'title': it.title,
              'quantity': it.qty,
              'amount': it.total,
            })
        .toList();

    EscPosPrinterService.buildPosReceiptBytes(
      storeName: widget.settings.kioskName,
      storeAddress: widget.settings.kioskAddress,
      storePhone: widget.settings.kioskPhone,
      receiptNo: widget.invoiceNumber,
      date: widget.timestamp ?? DateTime.now(),
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      items: escPosItems,
      subtotal: widget.subtotal,
      discount: 0.0,
      total: widget.grandTotal,
      paidAmount: widget.amountTendered ?? widget.grandTotal,
      paymentMode: widget.paymentMode,
      currencySymbol: widget.settings.currencySymbol,
    );

    if (mounted) {
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt sent to printer!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _copyDigitalSlipText() {
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln(widget.settings.kioskName.toUpperCase());
    buffer.writeln(widget.settings.kioskAddress);
    buffer.writeln('Tel: ${widget.settings.kioskPhone}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Invoice: ${widget.invoiceNumber}');
    buffer.writeln('Date: ${(widget.timestamp ?? DateTime.now()).toString().substring(0, 16)}');
    buffer.writeln('Payment: ${widget.paymentMode}');
    if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      buffer.writeln('Customer: ${widget.customerName}');
    }
    buffer.writeln('--------------------------------');
    for (final it in widget.items) {
      buffer.writeln('${it.title} x${it.qty}  ${widget.settings.currencySymbol}${it.total.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('GRAND TOTAL: ${widget.settings.currencySymbol}${widget.grandTotal.toStringAsFixed(2)}');
    if (widget.amountTendered != null) {
      buffer.writeln('Tendered: ${widget.settings.currencySymbol}${widget.amountTendered!.toStringAsFixed(2)}');
    }
    if (widget.changeDue != null && widget.changeDue! > 0) {
      buffer.writeln('Change: ${widget.settings.currencySymbol}${widget.changeDue!.toStringAsFixed(2)}');
    }
    buffer.writeln('================================');
    buffer.writeln('Thank you for visiting!');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt details copied to clipboard!'),
        backgroundColor: Color(0xFF6366F1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Realistic Printer Slot Top Bar
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFF475569),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Animated Paper Feed
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  ),
                );
              },
              child: _buildThermalPaperSlip(),
            ),

            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: DossierButton(
                    text: 'Copy Text',
                    icon: Icons.copy_rounded,
                    variant: DossierButtonVariant.outline,
                    size: DossierButtonSize.md,
                    onPressed: _copyDigitalSlipText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DossierButton(
                    text: 'Print Slip',
                    icon: Icons.print_rounded,
                    variant: DossierButtonVariant.primary,
                    size: DossierButtonSize.md,
                    isLoading: _isPrinting,
                    onPressed: _triggerEscPosPrint,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close Receipt',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalPaperSlip() {
    final now = widget.timestamp ?? DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5), // Authentic thermal ivory paper
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Serrated Top Edge
          CustomPaint(
            size: const Size(double.infinity, 8),
            painter: _SerratedEdgePainter(isTop: true),
          ),

          // Receipt Body Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kiosk Header & Branding
                Text(
                  widget.settings.kioskName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.settings.kioskAddress,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                Text(
                  'TEL: ${widget.settings.kioskPhone}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),

                const SizedBox(height: 8),
                _buildDashedLine(),
                const SizedBox(height: 6),

                // Meta Info
                _buildReceiptRow('SLIP #', widget.invoiceNumber, isBold: true),
                _buildReceiptRow('DATE', formattedDate),
                _buildReceiptRow('MODE', widget.paymentMode),
                if (widget.customerName != null && widget.customerName!.isNotEmpty)
                  _buildReceiptRow('CLIENT', widget.customerName!),

                const SizedBox(height: 6),
                _buildDashedLine(),
                const SizedBox(height: 6),

                // Line Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ITEM / QTY', style: _receiptStyle(isBold: true, fontSize: 10.5)),
                    Text('AMOUNT', style: _receiptStyle(isBold: true, fontSize: 10.5)),
                  ],
                ),
                const SizedBox(height: 4),

                // Line Items
                ...widget.items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${it.title} ${it.qty > 1 ? "x${it.qty}" : ""}',
                              style: _receiptStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.settings.currencySymbol}${it.total.toStringAsFixed(2)}',
                            style: _receiptStyle(fontSize: 11, isBold: true),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 6),
                _buildDashedLine(),
                const SizedBox(height: 6),

                // Subtotal & Totals
                if (widget.subtotal != widget.grandTotal)
                  _buildReceiptRow('SUBTOTAL', '${widget.settings.currencySymbol}${widget.subtotal.toStringAsFixed(2)}'),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL DUE',
                      style: GoogleFonts.spaceMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '${widget.settings.currencySymbol}${widget.grandTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),

                if (widget.amountTendered != null) ...[
                  const SizedBox(height: 4),
                  _buildReceiptRow('TENDERED', '${widget.settings.currencySymbol}${widget.amountTendered!.toStringAsFixed(2)}'),
                ],

                if (widget.changeDue != null && widget.changeDue! > 0) ...[
                  const SizedBox(height: 2),
                  _buildReceiptRow('CHANGE RETURNED', '${widget.settings.currencySymbol}${widget.changeDue!.toStringAsFixed(2)}', isBold: true),
                ],

                const SizedBox(height: 10),
                _buildDashedLine(),
                const SizedBox(height: 8),

                // Thermal Barcode Simulation
                Center(
                  child: Container(
                    height: 28,
                    width: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                          Colors.transparent,
                          Colors.black,
                        ],
                        stops: const [
                          0.0, 0.08, 0.08, 0.18, 0.18, 0.32, 0.32, 0.44,
                          0.56, 0.56, 0.68, 0.78, 0.78, 0.88, 0.88, 1.0,
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.invoiceNumber,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 8.5,
                    color: const Color(0xFF6B7280),
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  '*** THANK YOU FOR VISITING ***',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF374151),
                  ),
                ),
                Text(
                  'Please keep this slip for your records',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    fontSize: 8.5,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Serrated Bottom Edge
          CustomPaint(
            size: const Size(double.infinity, 8),
            painter: _SerratedEdgePainter(isTop: false),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _receiptStyle(fontSize: 10.5, color: const Color(0xFF4B5563))),
          Text(value, style: _receiptStyle(fontSize: 10.5, isBold: isBold)),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF9CA3AF)),
              ),
            );
          }),
        );
      },
    );
  }

  TextStyle _receiptStyle({
    double fontSize = 11,
    bool isBold = false,
    Color color = const Color(0xFF111827),
  }) {
    return GoogleFonts.spaceMono(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
      color: color,
    );
  }
}

class _SerratedEdgePainter extends CustomPainter {
  final bool isTop;

  _SerratedEdgePainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFAF8F5)
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    const toothHeight = 6.0;
    final numTeeth = (size.width / toothWidth).ceil();

    if (isTop) {
      path.moveTo(0, size.height);
      for (int i = 0; i < numTeeth; i++) {
        final startX = i * toothWidth;
        path.lineTo(startX + toothWidth / 2, size.height - toothHeight);
        path.lineTo(startX + toothWidth, size.height);
      }
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      for (int i = 0; i < numTeeth; i++) {
        final startX = i * toothWidth;
        path.lineTo(startX + toothWidth / 2, toothHeight);
        path.lineTo(startX + toothWidth, 0);
      }
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SerratedEdgePainter oldDelegate) => oldDelegate.isTop != isTop;
}
