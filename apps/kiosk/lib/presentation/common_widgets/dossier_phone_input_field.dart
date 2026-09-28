import 'package:flutter/material.dart';
import 'package:dossier/core/models/country_code.dart';
import 'package:dossier/presentation/common_widgets/dossier_country_picker.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';

/// Reusable Mobile Number Input Field with integrated Country Code Picker
class DossierPhoneInputField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Widget? trailing;

  const DossierPhoneInputField({
    super.key,
    this.label = 'Mobile Number',
    this.hintText,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.onChanged,
    this.autofocus = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: DossierCountryPicker(
                selectedCountry: selectedCountry,
                onCountryChanged: onCountryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DossierInputField(
                label: label,
                hintText: hintText ?? selectedCountry.example,
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: autofocus,
                onChanged: onChanged,
                prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
