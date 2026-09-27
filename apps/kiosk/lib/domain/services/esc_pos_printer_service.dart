import 'dart:convert';
import 'dart:typed_data';

enum ThermalPaperWidth {
  mm58(32),
  mm80(48);

  final int maxCharsPerLine;
  const ThermalPaperWidth(this.maxCharsPerLine);
}

class EscPosPrinterService {
  // ESC/POS Command Constants
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;
  static const int ff = 0x0C;

  /// Initializes the printer to default state
  static List<int> init() => [esc, 0x40];

  /// Sets text alignment: 0=Left, 1=Center, 2=Right
  static List<int> align(int alignment) => [esc, 0x61, alignment.clamp(0, 2)];

  /// Bold text mode: true=On, false=Off
  static List<int> setBold(bool isBold) => [esc, 0x45, isBold ? 1 : 0];

  /// Underline mode: 0=Off, 1=1 dot, 2=2 dots
  static List<int> setUnderline(int dots) => [esc, 0x2D, dots.clamp(0, 2)];

  /// Sets text size multiplier: width (1-8), height (1-8)
  static List<int> setTextSize({int width = 1, int height = 1}) {
    final w = (width - 1).clamp(0, 7);
    final h = (height - 1).clamp(0, 7);
    return [gs, 0x21, (w << 4) | h];
  }

  /// Feeds [lines] blank lines
  static List<int> feedLines(int lines) => [esc, 0x64, lines.clamp(1, 255)];

  /// Cut paper command (partial or full)
  static List<int> cutPaper({bool partial = false}) => [gs, 0x56, partial ? 66 : 65, 0];

  /// Kick cash drawer pulse (pin 2, 25ms on, 250ms off)
  static List<int> openCashDrawer() => [esc, 0x70, 0, 25, 250];

  /// Generates a divider line across the paper width
  static String divider({ThermalPaperWidth width = ThermalPaperWidth.mm58, String char = '-'}) {
    return char * width.maxCharsPerLine;
  }

  /// Generates a two-column row with left label and right value aligned to printer width
  static String rowTwoColumns(
    String left,
    String right, {
    ThermalPaperWidth width = ThermalPaperWidth.mm58,
  }) {
    final max = width.maxCharsPerLine;
    final totalLen = left.length + right.length;
    if (totalLen >= max) {
      final availableLeft = (max - right.length - 1).clamp(1, max);
      final truncatedLeft = left.length > availableLeft ? left.substring(0, availableLeft) : left;
      final spaces = ' ' * (max - (truncatedLeft.length + right.length)).clamp(1, max);
      return '$truncatedLeft$spaces$right';
    }
    final spaces = ' ' * (max - totalLen);
    return '$left$spaces$right';
  }

  /// Builds a complete ESC/POS raw byte payload for a Walk-in POS / Case Receipt
  static Uint8List buildPosReceiptBytes({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String receiptNo,
    required DateTime date,
    required String? customerName,
    required String? customerPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
    required String paymentMode,
    String? upiQrString,
    String currencySymbol = '₹',
    ThermalPaperWidth width = ThermalPaperWidth.mm58,
    String footerNote = 'Thank you for your visit!',
  }) {
    final bytes = <int>[];

    void writeText(String text, {bool newline = true}) {
      bytes.addAll(utf8.encode(text));
      if (newline) bytes.add(lf);
    }

    // 1. Init & Center Header
    bytes.addAll(init());
    bytes.addAll(align(1)); // Center
    bytes.addAll(setTextSize(width: 2, height: 2));
    bytes.addAll(setBold(true));
    writeText(storeName);

    bytes.addAll(setTextSize(width: 1, height: 1));
    bytes.addAll(setBold(false));
    if (storeAddress.isNotEmpty) writeText(storeAddress);
    if (storePhone.isNotEmpty) writeText('Tel: $storePhone');
    bytes.addAll(align(1));
    writeText(divider(width: width, char: '='));

    // 2. Receipt Meta
    bytes.addAll(align(0)); // Left
    writeText(rowTwoColumns('Receipt #: $receiptNo', date.toIso8601String().substring(11, 16), width: width));
    writeText(rowTwoColumns('Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}', 'Mode: $paymentMode', width: width));
    if (customerName != null && customerName.isNotEmpty) {
      writeText('Customer: $customerName ${customerPhone != null && customerPhone.isNotEmpty ? "($customerPhone)" : ""}');
    }
    writeText(divider(width: width));

    // 3. Items Table Header
    bytes.addAll(setBold(true));
    writeText(rowTwoColumns('ITEM / SERVICE', 'AMOUNT', width: width));
    bytes.addAll(setBold(false));
    writeText(divider(width: width));

    // 4. Line Items
    for (final item in items) {
      final title = item['title'] as String? ?? 'Service';
      final qty = item['quantity'] as int? ?? 1;
      final amount = (item['amount'] as num? ?? 0.0).toDouble();
      final itemLabel = qty > 1 ? '$title x$qty' : title;
      final amountStr = '$currencySymbol${amount.toStringAsFixed(2)}';
      writeText(rowTwoColumns(itemLabel, amountStr, width: width));
    }

    writeText(divider(width: width));

    // 5. Totals
    if (discount > 0) {
      writeText(rowTwoColumns('Subtotal:', '$currencySymbol${subtotal.toStringAsFixed(2)}', width: width));
      writeText(rowTwoColumns('Discount:', '-$currencySymbol${discount.toStringAsFixed(2)}', width: width));
    }
    bytes.addAll(setBold(true));
    bytes.addAll(setTextSize(width: 1, height: 2));
    writeText(rowTwoColumns('TOTAL DUE:', '$currencySymbol${total.toStringAsFixed(2)}', width: width));
    bytes.addAll(setTextSize(width: 1, height: 1));
    writeText(rowTwoColumns('PAID AMOUNT:', '$currencySymbol${paidAmount.toStringAsFixed(2)}', width: width));
    final balance = (total - paidAmount).clamp(0.0, double.infinity);
    if (balance > 0) {
      writeText(rowTwoColumns('BALANCE DUE:', '$currencySymbol${balance.toStringAsFixed(2)}', width: width));
    }
    bytes.addAll(setBold(false));
    writeText(divider(width: width, char: '='));

    // 6. Footer & Cut
    bytes.addAll(align(1)); // Center
    writeText(footerNote);
    writeText('Powered by Dossier Kiosk OS');
    bytes.addAll(feedLines(3));
    bytes.addAll(cutPaper(partial: true));

    return Uint8List.fromList(bytes);
  }

  /// Builds a complete End-Of-Day (EOD) Cash Reconciliation Register Slip
  static Uint8List buildEodRegisterBytes({
    required String kioskName,
    required String operatorName,
    required DateTime reportDate,
    required int totalInvoices,
    required double totalGrossSales,
    required double totalCashCollected,
    required double totalUpiCollected,
    required double totalPendingDues,
    required double drawerOpeningCash,
    required double drawerPhysicalCash,
    required Map<String, int> serviceBreakdown,
    String currencySymbol = '₹',
    ThermalPaperWidth width = ThermalPaperWidth.mm58,
  }) {
    final bytes = <int>[];

    void writeText(String text, {bool newline = true}) {
      bytes.addAll(utf8.encode(text));
      if (newline) bytes.add(lf);
    }

    bytes.addAll(init());
    bytes.addAll(align(1));
    bytes.addAll(setTextSize(width: 1, height: 2));
    bytes.addAll(setBold(true));
    writeText('*** DAILY EOD REGISTER ***');
    bytes.addAll(setTextSize(width: 1, height: 1));
    writeText(kioskName);
    writeText(divider(width: width, char: '='));

    // Meta
    bytes.addAll(align(0));
    bytes.addAll(setBold(false));
    writeText(rowTwoColumns('Date: ${reportDate.day.toString().padLeft(2, '0')}/${reportDate.month.toString().padLeft(2, '0')}/${reportDate.year}', 'Time: ${reportDate.hour.toString().padLeft(2, '0')}:${reportDate.minute.toString().padLeft(2, '0')}', width: width));
    writeText('Operator: $operatorName');
    writeText('Total Transactions: $totalInvoices');
    writeText(divider(width: width));

    // Financial Breakdown
    bytes.addAll(setBold(true));
    writeText('FINANCIAL SUMMARY:');
    bytes.addAll(setBold(false));
    writeText(rowTwoColumns('Total Gross Sales:', '$currencySymbol${totalGrossSales.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('Cash Collected:', '$currencySymbol${totalCashCollected.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('UPI / Online:', '$currencySymbol${totalUpiCollected.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('Pending Due:', '$currencySymbol${totalPendingDues.toStringAsFixed(2)}', width: width));
    writeText(divider(width: width));

    // Cash Drawer Reconciliation
    bytes.addAll(setBold(true));
    writeText('DRAWER RECONCILIATION:');
    bytes.addAll(setBold(false));
    final expectedCashInDrawer = drawerOpeningCash + totalCashCollected;
    final variance = drawerPhysicalCash - expectedCashInDrawer;

    writeText(rowTwoColumns('Opening Float:', '$currencySymbol${drawerOpeningCash.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('+ Cash Inflow:', '$currencySymbol${totalCashCollected.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('Expected In Drawer:', '$currencySymbol${expectedCashInDrawer.toStringAsFixed(2)}', width: width));
    writeText(rowTwoColumns('Physical Counted:', '$currencySymbol${drawerPhysicalCash.toStringAsFixed(2)}', width: width));
    
    bytes.addAll(setBold(true));
    final varianceLabel = variance == 0 ? 'BALANCED' : (variance > 0 ? 'OVERAGE (+$currencySymbol${variance.toStringAsFixed(2)})' : 'SHORTAGE (-$currencySymbol${variance.abs().toStringAsFixed(2)})');
    writeText(rowTwoColumns('Variance Status:', varianceLabel, width: width));
    bytes.addAll(setBold(false));
    writeText(divider(width: width));

    // Service Breakdown
    if (serviceBreakdown.isNotEmpty) {
      bytes.addAll(setBold(true));
      writeText('VOLUME BREAKDOWN:');
      bytes.addAll(setBold(false));
      serviceBreakdown.forEach((service, count) {
        writeText(rowTwoColumns(service, '$count orders', width: width));
      });
      writeText(divider(width: width, char: '='));
    }

    // Signatures
    bytes.addAll(align(1));
    writeText('Operator Sign: ________________');
    bytes.addAll(feedLines(1));
    writeText('Manager Sign:  ________________');
    bytes.addAll(feedLines(3));
    bytes.addAll(cutPaper(partial: true));

    return Uint8List.fromList(bytes);
  }
}
