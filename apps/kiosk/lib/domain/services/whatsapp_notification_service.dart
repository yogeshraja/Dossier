import 'package:url_launcher/url_launcher.dart';

class WhatsAppNotificationService {
  /// Send pickup alert with balance reminder
  static Future<bool> sendReadyForPickupAlert({
    required String phoneNumber,
    required String customerName,
    required String caseTitle,
    required double balanceDue,
    String kioskName = 'CSC & Cyber Services',
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final message = '''
Namaste $customerName ji,
Your application for *$caseTitle* is complete and ready for pickup at *$kioskName*.

${balanceDue > 0 ? "Remaining balance to pay: ₹${balanceDue.toStringAsFixed(0)}\n" : "Status: Fully Paid\n"}
Please collect your document during our normal working hours.
Thank you!
''';

    return _launchWhatsApp(formattedPhone, message);
  }

  /// Send missing document alert
  static Future<bool> sendMissingDocumentAlert({
    required String phoneNumber,
    required String customerName,
    required String caseTitle,
    required List<String> missingDocs,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final docListStr = missingDocs.map((d) => '• $d').join('\n');
    final message = '''
Namaste $customerName ji,
To complete your application for *$caseTitle*, we still need the following documents:

$docListStr

Please bring original or clear photos of these documents to our kiosk.
Thank you!
''';

    return _launchWhatsApp(formattedPhone, message);
  }

  static Future<bool> _launchWhatsApp(String phone, String message) async {
    final nativeUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(nativeUri)) {
      return await launchUrl(nativeUri);
    } else {
      final webUri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
