import 'package:flutter/material.dart';

enum DossierBadgeVariant {
  primary,
  success,
  warning,
  danger,
  info,
  neutral,
}

class DossierBadge extends StatefulWidget {
  final String? text;
  final String? label;
  final DossierBadgeVariant variant;
  final IconData? icon;
  final bool isPulse;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const DossierBadge({
    super.key,
    this.text,
    this.label,
    this.variant = DossierBadgeVariant.primary,
    this.icon,
    this.isPulse = false,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  }) : assert(text != null || label != null, 'Either text or label must be provided');

  String get effectiveText => text ?? label ?? '';

  @override
  State<DossierBadge> createState() => _DossierBadgeState();
}

class _DossierBadgeState extends State<DossierBadge> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    if (widget.isPulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      _animation = Tween<double>(begin: 0.85, end: 1.05).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color _getBgColor(bool isDark) {
    switch (widget.variant) {
      case DossierBadgeVariant.primary:
        return const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12);
      case DossierBadgeVariant.success:
        return const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12);
      case DossierBadgeVariant.warning:
        return const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12);
      case DossierBadgeVariant.danger:
        return const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.12);
      case DossierBadgeVariant.info:
        return const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.2 : 0.12);
      case DossierBadgeVariant.neutral:
        return isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0);
    }
  }

  Color _getTextColor(bool isDark) {
    switch (widget.variant) {
      case DossierBadgeVariant.primary:
        return isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
      case DossierBadgeVariant.success:
        return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      case DossierBadgeVariant.warning:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case DossierBadgeVariant.danger:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case DossierBadgeVariant.info:
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case DossierBadgeVariant.neutral:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = _getTextColor(isDark);
    final bgColor = _getBgColor(isDark);

    Widget badge = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: widget.fontSize + 1, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            widget.effectiveText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: widget.fontSize,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );

    if (widget.isPulse && _animation != null) {
      return ScaleTransition(
        scale: _animation!,
        child: badge,
      );
    }

    return badge;
  }
}
