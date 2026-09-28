import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';

class QuickTenderPad extends StatefulWidget {
  final double totalAmount;
  final double? initialTendered;
  final ValueChanged<double>? onTenderChanged;
  final void Function(double tenderedAmount, double changeAmount)? onCompletePayment;
  final bool isProcessing;

  const QuickTenderPad({
    super.key,
    required this.totalAmount,
    this.initialTendered,
    this.onTenderChanged,
    this.onCompletePayment,
    this.isProcessing = false,
  });

  @override
  State<QuickTenderPad> createState() => _QuickTenderPadState();
}

class _QuickTenderPadState extends State<QuickTenderPad> {
  late String _tenderInput;

  @override
  void initState() {
    super.initState();
    _tenderInput = widget.initialTendered != null && widget.initialTendered! > 0
        ? widget.initialTendered!.toStringAsFixed(widget.initialTendered! % 1 == 0 ? 0 : 2)
        : widget.totalAmount.toStringAsFixed(widget.totalAmount % 1 == 0 ? 0 : 2);
  }

  double get _currentTendered {
    return double.tryParse(_tenderInput) ?? 0.0;
  }

  double get _changeAmount {
    final diff = _currentTendered - widget.totalAmount;
    return diff > 0 ? diff : 0.0;
  }

  double get _shortfallAmount {
    final diff = widget.totalAmount - _currentTendered;
    return diff > 0 ? diff : 0.0;
  }

  void _updateTender(String value) {
    setState(() {
      _tenderInput = value;
    });
    widget.onTenderChanged?.call(_currentTendered);
  }

  void _handleDigit(String digit) {
    if (_tenderInput == '0' && digit != '.') {
      _updateTender(digit);
      return;
    }
    if (digit == '.' && _tenderInput.contains('.')) return;
    _updateTender('$_tenderInput$digit');
  }

  void _handleBackspace() {
    if (_tenderInput.isNotEmpty) {
      final updated = _tenderInput.substring(0, _tenderInput.length - 1);
      _updateTender(updated.isEmpty ? '0' : updated);
    }
  }

  void _handleClear() {
    _updateTender('0');
  }

  void _setExact() {
    final formatted = widget.totalAmount.toStringAsFixed(widget.totalAmount % 1 == 0 ? 0 : 2);
    _updateTender(formatted);
  }

  void _addAmount(double add) {
    final updated = _currentTendered + add;
    _updateTender(updated.toStringAsFixed(updated % 1 == 0 ? 0 : 2));
  }

  List<double> _generateSmartChips() {
    final total = widget.totalAmount;
    final Set<double> chips = {};

    // Standard cash denominations
    final denominations = [50.0, 100.0, 200.0, 500.0, 2000.0];
    for (final d in denominations) {
      if (d >= total) {
        chips.add(d);
      }
    }

    // Nearest rounded amounts
    if (total > 0) {
      final next50 = (total / 50).ceil() * 50.0;
      final next100 = (total / 100).ceil() * 100.0;
      final next500 = (total / 500).ceil() * 500.0;
      if (next50 > total) chips.add(next50);
      if (next100 > total) chips.add(next100);
      if (next500 > total) chips.add(next500);
    }

    final list = chips.toList()..sort();
    return list.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final smartChips = _generateSmartChips();
    final isExact = _currentTendered == widget.totalAmount;
    final isOver = _currentTendered > widget.totalAmount;
    final isUnder = _currentTendered < widget.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total Due vs Tendered Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BILL TOTAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${widget.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CASH TENDERED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_currentTendered.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Return Change Status Indicator Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOver || isExact
                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOver || isExact
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isOver || isExact ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                      size: 20,
                      color: isOver || isExact ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isExact
                          ? 'Exact Payment Tendered'
                          : isOver
                              ? 'Return Customer Change'
                              : 'Cash Shortfall Due',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isOver || isExact
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
                Text(
                  isExact
                      ? '₹0.00'
                      : isOver
                          ? '₹${_changeAmount.toStringAsFixed(2)}'
                          : '₹${_shortfallAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isOver || isExact
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Smart Quick Denomination Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.check_rounded, size: 14),
                label: Text('Exact (₹${widget.totalAmount.toStringAsFixed(0)})'),
                backgroundColor: isExact
                    ? primaryColor.withValues(alpha: 0.25)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                side: BorderSide(
                  color: isExact ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                onPressed: _setExact,
              ),
              ...smartChips.map((chipVal) => ActionChip(
                    label: Text('₹${chipVal.toStringAsFixed(0)}'),
                    backgroundColor: _currentTendered == chipVal
                        ? primaryColor.withValues(alpha: 0.25)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    side: BorderSide(
                      color: _currentTendered == chipVal
                          ? primaryColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    onPressed: () => _updateTender(chipVal.toStringAsFixed(0)),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 14),
                label: const Text('+₹50'),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                onPressed: () => _addAmount(50),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 14),
                label: const Text('+₹100'),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                onPressed: () => _addAmount(100),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Touch Numeric Numpad
          _buildNumpad(isDark),

          const SizedBox(height: 14),

          // Complete Action Button
          DossierButton(
            text: isUnder
                ? 'Tender Partial (Shortfall ₹${_shortfallAmount.toStringAsFixed(2)})'
                : 'Complete Tender (Change ₹${_changeAmount.toStringAsFixed(2)})',
            icon: Icons.check_circle_rounded,
            variant: isUnder ? DossierButtonVariant.outline : DossierButtonVariant.success,
            size: DossierButtonSize.lg,
            isFullWidth: true,
            isLoading: widget.isProcessing,
            onPressed: () {
              widget.onCompletePayment?.call(_currentTendered, _changeAmount);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(bool isDark) {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: buttons.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: _buildNumpadKey(key, isDark),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadKey(String key, bool isDark) {
    final isClear = key == 'C';
    final isBackspace = key == '⌫';
    final isAction = isClear || isBackspace;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isClear) {
            _handleClear();
          } else if (isBackspace) {
            _handleBackspace();
          } else {
            _handleDigit(key);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isAction
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: isBackspace
              ? Icon(Icons.backspace_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
              : Text(
                  key,
                  style: GoogleFonts.spaceMono(
                    fontSize: 16,
                    fontWeight: isAction ? FontWeight.bold : FontWeight.w700,
                    color: isClear
                        ? const Color(0xFFEF4444)
                        : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                  ),
                ),
        ),
      ),
    );
  }
}
