class UpiQrService {
  /// Builds an NPCI-standard UPI deep-link URI
  /// e.g. upi://pay?pa=csckiosk@oksbi&pn=Main+Market+CSC&am=132.00&tr=INV-2026-0042&cu=INR
  static String generateUpiPayload({
    required String merchantVpa,
    required String merchantName,
    required double amount,
    required String transactionId,
    String? note,
  }) {
    final cleanVpa = merchantVpa.trim();
    final cleanName = Uri.encodeComponent(merchantName.trim());
    final amountFormatted = amount.toStringAsFixed(2);
    final cleanTr = Uri.encodeComponent(transactionId.trim());
    final cleanNote = Uri.encodeComponent(note ?? 'Dossier Payment');

    return 'upi://pay?pa=$cleanVpa&pn=$cleanName&am=$amountFormatted&tr=$cleanTr&cu=INR&tn=$cleanNote';
  }
}
