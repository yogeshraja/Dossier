import 'package:flutter/material.dart';

enum DossierCardVariant {
  elevated,
  outlined,
  glass,
  flat,
  gradient,
}

class DossierCard extends StatefulWidget {
  final Widget? child;
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? badge;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final DossierCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? gradient;
  final double elevation;
  final double hoverElevation;
  final bool isSelected;
  final bool animateHover;

  const DossierCard({
    super.key,
    this.child,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.variant = DossierCardVariant.outlined,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 14,
    this.backgroundColor,
    this.borderColor,
    this.gradient,
    this.elevation = 0,
    this.hoverElevation = 4,
    this.isSelected = false,
    this.animateHover = true,
  });

  @override
  State<DossierCard> createState() => _DossierCardState();
}

class _DossierCardState extends State<DossierCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    Color resolvedBgColor;
    Border? resolvedBorder;
    Gradient? resolvedGradient = widget.gradient;

    switch (widget.variant) {
      case DossierCardVariant.elevated:
        resolvedBgColor = widget.backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
        resolvedBorder = widget.isSelected
            ? Border.all(color: primaryColor, width: 2)
            : Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1);
        break;

      case DossierCardVariant.outlined:
        resolvedBgColor = widget.backgroundColor ?? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : Colors.white);
        resolvedBorder = widget.isSelected
            ? Border.all(color: primaryColor, width: 2)
            : Border.all(
                color: widget.borderColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: widget.isSelected ? 2 : 1,
              );
        break;

      case DossierCardVariant.glass:
        resolvedBgColor = widget.backgroundColor ??
            (isDark
                ? const Color(0xFF1E293B).withValues(alpha: _isHovered ? 0.85 : 0.65)
                : Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.8));
        resolvedBorder = Border.all(
          color: widget.isSelected
              ? primaryColor
              : (_isHovered
                  ? primaryColor.withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))),
          width: widget.isSelected ? 2 : 1,
        );
        break;

      case DossierCardVariant.flat:
        resolvedBgColor = widget.backgroundColor ?? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC));
        resolvedBorder = widget.isSelected ? Border.all(color: primaryColor, width: 2) : null;
        break;

      case DossierCardVariant.gradient:
        resolvedBgColor = Colors.transparent;
        resolvedGradient = widget.gradient ??
            LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
        resolvedBorder = Border.all(
          color: widget.isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: widget.isSelected ? 2 : 1,
        );
        break;
    }

    final double currentElevation = _isHovered && widget.animateHover ? widget.hoverElevation : widget.elevation;

    Widget content = widget.child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null || widget.leading != null || widget.trailing != null || widget.badge != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 12),
                  ],
                  if (widget.title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.badge != null) ...[
                                const SizedBox(width: 8),
                                widget.badge!,
                              ],
                            ],
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            if (widget.footer != null) ...[
              const SizedBox(height: 12),
              widget.footer!,
            ],
          ],
        );

    Widget cardBody = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: resolvedBgColor,
        gradient: resolvedGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: resolvedBorder,
        boxShadow: [
          if (currentElevation > 0)
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.06),
              blurRadius: currentElevation * 3,
              offset: Offset(0, currentElevation),
            ),
          if (_isHovered && widget.animateHover && widget.onTap != null)
            BoxShadow(
              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap != null
              ? () {
                  _controller.forward().then((_) => _controller.reverse());
                  widget.onTap!();
                }
              : null,
          onLongPress: widget.onLongPress,
          onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
          onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
          onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
          child: Padding(
            padding: widget.padding,
            child: content,
          ),
        ),
      ),
    );

    if (widget.onTap != null && widget.animateHover) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}
