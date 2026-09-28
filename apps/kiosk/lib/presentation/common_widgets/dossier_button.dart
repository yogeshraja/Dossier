import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DossierButtonVariant {
  primary,
  secondary,
  outline,
  danger,
  success,
  warning,
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
  final String? tooltip;
  final bool enableRainbowHover;

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
    this.tooltip,
    this.enableRainbowHover = true,
  });

  @override
  State<DossierButton> createState() => _DossierButtonState();
}

class _DossierButtonState extends State<DossierButton> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rainbowController;
  late AnimationController _hoverFadeController;
  late Animation<double> _hoverFadeAnimation;
  bool _isHovered = false;

  static const List<Color> _rainbowColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF6366F1), // Seamless loop
  ];

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _hoverFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _hoverFadeAnimation = CurvedAnimation(
      parent: _hoverFadeController,
      curve: Curves.easeOut,
    );

    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverFadeController.dispose();
    _rainbowController.dispose();
    super.dispose();
  }

  void _onEnter() {
    if (!mounted || widget.onPressed == null || widget.isLoading) return;
    setState(() => _isHovered = true);
    _hoverFadeController.forward();
    if (widget.enableRainbowHover) {
      _rainbowController.repeat();
    }
  }

  void _onExit() {
    if (!mounted) return;
    setState(() => _isHovered = false);
    _hoverFadeController.reverse();
    if (widget.enableRainbowHover) {
      _rainbowController.stop();
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case DossierButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 7);
      case DossierButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case DossierButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 14);
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
        return 16;
      case DossierButtonSize.lg:
        return 19;
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
      case DossierButtonVariant.warning:
        return const Color(0xFFF59E0B);
      case DossierButtonVariant.success:
        return const Color(0xFF10B981);
      case DossierButtonVariant.outline:
      case DossierButtonVariant.ghost:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = _getBaseColor(context);
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final radius = widget.borderRadius ?? 10.0;

    Color bgColor;
    Color fgColor;

    switch (widget.variant) {
      case DossierButtonVariant.primary:
      case DossierButtonVariant.secondary:
      case DossierButtonVariant.danger:
      case DossierButtonVariant.warning:
      case DossierButtonVariant.success:
        bgColor = isDisabled
            ? baseColor.withValues(alpha: 0.35)
            : (_isHovered ? baseColor.withValues(alpha: 0.9) : baseColor);
        fgColor = Colors.white;
        break;
      case DossierButtonVariant.outline:
        bgColor = _isHovered ? baseColor.withValues(alpha: 0.1) : Colors.transparent;
        fgColor = isDisabled ? baseColor.withValues(alpha: 0.4) : baseColor;
        break;
      case DossierButtonVariant.ghost:
        bgColor = _isHovered ? baseColor.withValues(alpha: 0.08) : Colors.transparent;
        fgColor = isDisabled ? baseColor.withValues(alpha: 0.4) : baseColor;
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
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fgColor,
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (!widget.isLoading && widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: _getIconSize(), color: fgColor),
        ],
      ],
    );

    Widget buttonWidget = MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _pressController.forward(),
        onTapUp: isDisabled ? null : (_) => _pressController.reverse(),
        onTapCancel: isDisabled ? null : () => _pressController.reverse(),
        onTap: isDisabled ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hoverFadeAnimation, _rainbowController]),
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter: (widget.enableRainbowHover && !isDisabled && _hoverFadeAnimation.value > 0.01)
                    ? _RainbowBorderPainter(
                        progress: _rainbowController.value,
                        opacity: _hoverFadeAnimation.value,
                        borderRadius: radius,
                        borderWidth: 1.5,
                      )
                    : null,
                child: Container(
                  padding: _getPadding(),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(radius),
                    border: (widget.variant == DossierButtonVariant.outline && (_hoverFadeAnimation.value < 0.99 || !widget.enableRainbowHover))
                        ? Border.all(
                            color: isDisabled
                                ? baseColor.withValues(alpha: 0.25)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 1,
                          )
                        : null,
                    boxShadow: _isHovered && !isDisabled
                        ? [
                            BoxShadow(
                              color: (widget.variant == DossierButtonVariant.primary ||
                                      widget.variant == DossierButtonVariant.danger ||
                                      widget.variant == DossierButtonVariant.success)
                                  ? baseColor.withValues(alpha: 0.28)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );

    final tooltipMessage = (widget.tooltip != null && widget.tooltip!.isNotEmpty)
        ? widget.tooltip!
        : widget.text;

    if (tooltipMessage.isNotEmpty) {
      return Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 350),
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}

class _RainbowBorderPainter extends CustomPainter {
  final double progress;
  final double opacity;
  final double borderRadius;
  final double borderWidth;

  _RainbowBorderPainter({
    required this.progress,
    required this.opacity,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;

    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius - borderWidth / 2));

    // Linear gradient animated left to right with angle sweep
    final angle = progress * 2 * math.pi;
    final dx = math.cos(angle);
    final dy = math.sin(angle);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment(-dx, -dy),
        end: Alignment(dx, dy),
        colors: _DossierButtonState._rainbowColors
            .map((c) => c.withValues(alpha: (c.a * opacity).clamp(0.0, 1.0)))
            .toList(),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RainbowBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}

