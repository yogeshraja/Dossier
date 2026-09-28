import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

enum DossierToastVariant {
  success(Color(0xFF10B981), Icons.check_circle_rounded),
  info(Color(0xFF6366F1), Icons.info_rounded),
  warning(Color(0xFFF59E0B), Icons.warning_rounded),
  danger(Color(0xFFEF4444), Icons.error_rounded);

  final Color color;
  final IconData icon;
  const DossierToastVariant(this.color, this.icon);
}

/// Floating glassmorphic notification banner with countdown timer and interactive actions.
class DossierToast {
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    DossierToastVariant variant = DossierToastVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _DossierToastWidget(
        title: title,
        message: message,
        variant: variant,
        actionLabel: actionLabel,
        onAction: () {
          onAction?.call();
          entry.remove();
        },
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _DossierToastWidget extends StatefulWidget {
  final String title;
  final String? message;
  final DossierToastVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _DossierToastWidget({
    required this.title,
    this.message,
    required this.variant,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_DossierToastWidget> createState() => _DossierToastWidgetState();
}

class _DossierToastWidgetState extends State<_DossierToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      _dismissWithAnimation();
    });
  }

  void _dismissWithAnimation() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final toastWidth = screenWidth > 500 ? 420.0 : (screenWidth - 32);

    return Positioned(
      bottom: 24,
      right: screenWidth > 500 ? 24 : 16,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: toastWidth,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => widget.onDismiss(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.variant.color.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.variant.color.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status Icon Badge
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.variant.color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.variant.icon,
                                    color: widget.variant.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Title & Message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (widget.message != null && widget.message!.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          widget.message!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                      if (widget.actionLabel != null && widget.onAction != null) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: widget.onAction,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  widget.actionLabel!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: widget.variant.color,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.arrow_forward_rounded, size: 12, color: widget.variant.color),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Close Button
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  color: Colors.grey,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 16,
                                  onPressed: _dismissWithAnimation,
                                ),
                              ],
                            ),
                          ),

                          // Countdown Progress Bar
                          _CountdownBar(
                            duration: widget.duration,
                            color: widget.variant.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownBar extends StatefulWidget {
  final Duration duration;
  final Color color;

  const _CountdownBar({required this.duration, required this.color});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        return LinearProgressIndicator(
          value: 1.0 - _progressController.value,
          minHeight: 2.5,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(widget.color),
        );
      },
    );
  }
}
