import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/core/models/country_code.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';

/// Interactive Country Code Picker Chip and Selector Dialog
class DossierCountryPicker extends StatelessWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final bool isCompact;

  const DossierCountryPicker({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.isCompact = false,
  });

  void _showPickerDialog(BuildContext context) {
    showDialog<CountryCode>(
      context: context,
      builder: (ctx) => _CountryCodeSelectionModal(
        selected: selectedCountry,
      ),
    ).then((chosen) {
      if (chosen != null) {
        onCountryChanged(chosen);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Country: ${selectedCountry.name} (${selectedCountry.dialCode}) — Tap to change',
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => _showPickerDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: isCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedCountry.flag,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  selectedCountry.dialCode,
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCodeSelectionModal extends StatefulWidget {
  final CountryCode selected;

  const _CountryCodeSelectionModal({
    required this.selected,
  });

  @override
  State<_CountryCodeSelectionModal> createState() => _CountryCodeSelectionModalState();
}

class _CountryCodeSelectionModalState extends State<_CountryCodeSelectionModal> {
  final _searchCtrl = TextEditingController();
  List<CountryCode> _filtered = CountryCode.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = CountryCode.all;
      } else {
        _filtered = CountryCode.all.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.dialCode.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DossierDialog(
      title: 'Select Country Code',
      icon: Icons.public_rounded,
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
          maxHeight: 460,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DossierInputField(
              key: const ValueKey('country_code_search_field'),
              label: 'Search Country',
              hintText: 'e.g. United Kingdom, +44, US...',
              controller: _searchCtrl,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No countries matching "${_searchCtrl.text}"',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, index) {
                        final country = _filtered[index];
                        final isSelected = country.code == widget.selected.code;

                        return Material(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(country),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Text(country.flag, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      country.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF6366F1)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      country.dialCode,
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? const Color(0xFF6366F1)
                                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF6366F1)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
