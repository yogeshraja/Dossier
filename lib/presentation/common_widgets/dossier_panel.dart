import 'package:flutter/material.dart';

class DossierPanel extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? badge;
  final List<Widget>? actions;
  final Widget child;
  final bool isCollapsible;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry headerPadding;
  final Color? backgroundColor;
  final Color? headerColor;
  final double borderRadius;

  const DossierPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.badge,
    this.actions,
    required this.child,
    this.isCollapsible = false,
    this.initiallyExpanded = true,
    this.onExpansionChanged,
    this.contentPadding = const EdgeInsets.all(16),
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor,
    this.headerColor,
    this.borderRadius = 14,
  });

  @override
  State<DossierPanel> createState() => _DossierPanelState();
}

class _DossierPanelState extends State<DossierPanel> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _heightFactor = _controller.drive(
      CurveTween(curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(DossierPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded && widget.initiallyExpanded != _isExpanded) {
      _toggle();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final bgColor = widget.backgroundColor ?? (isDark ? const Color(0xFF0F172A) : Colors.white);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            onTap: widget.isCollapsible ? _toggle : null,
            child: Container(
              padding: widget.headerPadding,
              decoration: BoxDecoration(
                color: widget.headerColor ?? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
                border: Border(
                  bottom: BorderSide(
                    color: _isExpanded ? borderColor : Colors.transparent,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.actions != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions!,
                    ),
                  ],
                  if (widget.isCollapsible) ...[
                    const SizedBox(width: 4),
                    RotationTransition(
                      turns: _iconTurns,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Content
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller.view,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Padding(
                padding: widget.contentPadding,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
