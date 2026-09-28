import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DossierInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool showClearButton;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final bool isSearch;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final FocusNode? focusNode;

  const DossierInputField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.showClearButton = false,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.isSearch = false,
    this.borderRadius = 12,
    this.contentPadding,
    this.focusNode,
  });

  @override
  State<DossierInputField> createState() => _DossierInputFieldState();
}

class _DossierInputFieldState extends State<DossierInputField> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  bool _isFocused = false;
  bool _hasText = false;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _obscured = widget.obscureText;
    _hasText = _effectiveController.text.isNotEmpty;

    _effectiveController.addListener(_handleTextChange);
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  void _handleTextChange() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _effectiveFocusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant DossierInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      if (oldWidget.controller == null) {
        _effectiveController.dispose();
      }
      _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
      _hasText = _effectiveController.text.isNotEmpty;
      _effectiveController.addListener(_handleTextChange);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.dispose();
      }
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
      _isFocused = _effectiveFocusNode.hasFocus;
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
    if (widget.obscureText != oldWidget.obscureText) {
      setState(() {
        _obscured = widget.obscureText;
      });
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final effectiveRadius = widget.isSearch ? 24.0 : widget.borderRadius;

    Widget? suffix;
    if (widget.obscureText) {
      suffix = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    } else if (widget.showClearButton && _hasText && widget.enabled && !widget.readOnly) {
      suffix = IconButton(
        icon: Icon(
          Icons.cancel_rounded,
          size: 18,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        onPressed: () {
          _effectiveController.clear();
          widget.onChanged?.call('');
        },
      );
    } else {
      suffix = widget.suffixIcon;
    }

    Widget? prefix = widget.prefixIcon;
    if (widget.isSearch && prefix == null) {
      prefix = Icon(
        Icons.search_rounded,
        size: 20,
        color: _isFocused ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      );
    }

    final Color fillColor = widget.readOnly
        ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF1F5F9))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && !widget.isSearch) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(effectiveRadius),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: _effectiveController,
            focusNode: _effectiveFocusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            autofocus: widget.autofocus,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              helperText: widget.helperText,
              errorText: widget.errorText,
              filled: true,
              fillColor: fillColor,
              prefixIcon: prefix != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: prefix,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: suffix,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              contentPadding: widget.contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: widget.maxLines > 1 ? 12 : 12,
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
