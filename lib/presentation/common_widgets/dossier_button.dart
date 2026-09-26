import 'package:flutter/material.dart';

enum DossierButtonVariant {
  primary,
  secondary,
  outline,
  danger,
  success,
  ghost,
}

enum DossierButtonSize {
  sm,
  md,
  lg,
}

class DossierButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final DossierButtonVariant variant;
  final DossierButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;
  final double? borderRadius;

  const DossierButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = DossierButtonVariant.primary,
    this.size = DossierButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.borderRadius,
  });

  @override
  State<DossierButton> createState() => _DossierButtonState();
}

class _DossierButtonState extends State<DossierButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case DossierButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case DossierButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 18, vertical: 12);
      case DossierButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case DossierButtonSize.sm:
        return 12;
      case DossierButtonSize.md:
        return 13.5;
      case DossierButtonSize.lg:
        return 15;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case DossierButtonSize.sm:
        return 14;
      case DossierButtonSize.md:
        return 17;
      case DossierButtonSize.lg:
        return 20;
    }
  }

  Color _getBaseColor(BuildContext context) {
    if (widget.customColor != null) return widget.customColor!;
    switch (widget.variant) {
      case DossierButtonVariant.primary:
        return Theme.of(context).colorScheme.primary;
      case DossierButtonVariant.secondary:
        return Theme.of(context).colorScheme.secondary;
      case DossierButtonVariant.danger:
        return const Color(0xFFEF4444);
      case DossierButtonVariant.success:
        return const Color(0xFF10B981);
      case DossierButtonVariant.outline:
      case DossierButtonVariant.ghost:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getBaseColor(context);
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Color bgColor;
    Color fgColor;
    Border? border;

    switch (widget.variant) {
      case DossierButtonVariant.primary:
      case DossierButtonVariant.secondary:
      case DossierButtonVariant.danger:
      case DossierButtonVariant.success:
        bgColor = isDisabled ? baseColor.withValues(alpha: 0.4) : (_isHovered ? baseColor.withValues(alpha: 0.9) : baseColor);
        fgColor = Colors.white;
        break;
      case DossierButtonVariant.outline:
        bgColor = _isHovered ? baseColor.withValues(alpha: 0.1) : Colors.transparent;
        fgColor = baseColor;
        border = Border.all(color: isDisabled ? baseColor.withValues(alpha: 0.3) : baseColor, width: 1.2);
        break;
      case DossierButtonVariant.ghost:
        bgColor = _isHovered ? baseColor.withValues(alpha: 0.08) : Colors.transparent;
        fgColor = baseColor;
        break;
    }

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: _getIconSize(), color: fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            color: fgColor,
            fontSize: _getFontSize(),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (!widget.isLoading && widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: _getIconSize(), color: fgColor),
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _controller.forward(),
        onTapUp: isDisabled ? null : (_) => _controller.reverse(),
        onTapCancel: isDisabled ? null : () => _controller.reverse(),
        onTap: isDisabled ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: _getPadding(),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 10),
              border: border,
              boxShadow: _isHovered && !isDisabled && widget.variant == DossierButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: baseColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
