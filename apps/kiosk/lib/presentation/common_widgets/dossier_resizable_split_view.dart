import 'package:flutter/material.dart';
import 'package:dossier/core/constants/app_constants.dart';

/// Configuration for a single resizable pane within a [DossierResizableSplitView].
class ResizablePane {
  final Widget child;

  /// Explicit initial width (for horizontal) or height (for vertical) in logical pixels.
  final double? initialSize;

  /// Minimum allowed size in logical pixels.
  final double minSize;

  /// Maximum allowed size in logical pixels.
  final double maxSize;

  /// Whether this pane automatically stretches/shrinks to fill available remaining space.
  final bool isFlexible;

  /// Whether this pane is initially collapsed.
  final bool isCollapsed;

  /// Size when collapsed (default is 0.0).
  final double collapsedSize;

  /// Optional identifier for state persistence and debugging.
  final String? id;

  const ResizablePane({
    required this.child,
    this.initialSize,
    this.minSize = AppDimensions.panelMinWidth,
    this.maxSize = double.infinity,
    this.isFlexible = false,
    this.isCollapsed = false,
    this.collapsedSize = 0.0,
    this.id,
  });

  ResizablePane copyWith({
    Widget? child,
    double? initialSize,
    double? minSize,
    double? maxSize,
    bool? isFlexible,
    bool? isCollapsed,
    double? collapsedSize,
    String? id,
  }) {
    return ResizablePane(
      child: child ?? this.child,
      initialSize: initialSize ?? this.initialSize,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      isFlexible: isFlexible ?? this.isFlexible,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      collapsedSize: collapsedSize ?? this.collapsedSize,
      id: id ?? this.id,
    );
  }
}

/// A top-level, architectural multi-pane resizable layout widget.
///
/// Features:
/// - 60/120fps fluid drag handles with glowing visual feedback
/// - Clamped boundary enforcement (never overflows)
/// - Double-click / double-tap to reset or snap to default sizes
/// - Automatic responsive fallback for narrow / mobile viewports
/// - Full support for 2, 3, or N panes in horizontal or vertical orientation
class DossierResizableSplitView extends StatefulWidget {
  final List<ResizablePane> panes;
  final Axis direction;
  final double dividerThickness;
  final double hitAreaThickness;
  final double? responsiveBreakpoint;
  final ValueChanged<List<double>>? onSizesChanged;
  final Widget Function(BuildContext context, List<Widget> children)? responsiveStackedBuilder;

  const DossierResizableSplitView({
    super.key,
    required this.panes,
    this.direction = Axis.horizontal,
    this.dividerThickness = 1.0,
    this.hitAreaThickness = 10.0,
    this.responsiveBreakpoint,
    this.onSizesChanged,
    this.responsiveStackedBuilder,
  }) : assert(panes.length >= 2, 'DossierResizableSplitView requires at least 2 panes');

  @override
  State<DossierResizableSplitView> createState() => _DossierResizableSplitViewState();
}

class _DossierResizableSplitViewState extends State<DossierResizableSplitView> {
  List<double>? _currentSizes;
  int? _activeDraggingDividerIndex;
  int? _hoveredDividerIndex;
  double _lastTotalConstraint = 0.0;

  @override
  void didUpdateWidget(DossierResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panes.length != oldWidget.panes.length) {
      _currentSizes = null;
    }
  }

  void _initializeSizes(double totalAvailable) {
    final dividerTotalSpace = (widget.panes.length - 1) * widget.hitAreaThickness;
    final usableSpace = (totalAvailable - dividerTotalSpace).clamp(0.0, double.infinity);

    final flexibleIndices = <int>[];
    double allocatedFixedSpace = 0.0;

    for (int i = 0; i < widget.panes.length; i++) {
      final pane = widget.panes[i];
      if (pane.isFlexible) {
        flexibleIndices.add(i);
      } else if (pane.isCollapsed) {
        allocatedFixedSpace += pane.collapsedSize;
      } else if (pane.initialSize != null) {
        final clamped = pane.initialSize!.clamp(pane.minSize, pane.maxSize);
        allocatedFixedSpace += clamped;
      } else {
        flexibleIndices.add(i);
      }
    }

    if (flexibleIndices.isEmpty) {
      flexibleIndices.add(widget.panes.length - 1);
    }

    final remainingForFlexible = (usableSpace - allocatedFixedSpace).clamp(0.0, double.infinity);
    final perFlexibleSpace = remainingForFlexible / flexibleIndices.length;

    final sizes = List<double>.filled(widget.panes.length, 0.0);

    for (int i = 0; i < widget.panes.length; i++) {
      final pane = widget.panes[i];
      if (pane.isCollapsed) {
        sizes[i] = pane.collapsedSize;
      } else if (flexibleIndices.contains(i)) {
        sizes[i] = perFlexibleSpace.clamp(pane.minSize, pane.maxSize);
      } else {
        sizes[i] = (pane.initialSize ?? pane.minSize).clamp(pane.minSize, pane.maxSize);
      }
    }

    _currentSizes = sizes;
    _lastTotalConstraint = totalAvailable;
  }

  void _onDragUpdate(int dividerIndex, double delta, double totalAvailable) {
    if (_currentSizes == null) return;

    setState(() {
      final leftIndex = dividerIndex;
      final rightIndex = dividerIndex + 1;

      final leftPane = widget.panes[leftIndex];
      final rightPane = widget.panes[rightIndex];

      if (leftPane.isFlexible && !rightPane.isFlexible) {
        final currentRight = _currentSizes![rightIndex];
        final newRight = (currentRight - delta).clamp(rightPane.minSize, rightPane.maxSize);
        _currentSizes![rightIndex] = newRight;
      } else if (!leftPane.isFlexible && rightPane.isFlexible) {
        final currentLeft = _currentSizes![leftIndex];
        final newLeft = (currentLeft + delta).clamp(leftPane.minSize, leftPane.maxSize);
        _currentSizes![leftIndex] = newLeft;
      } else {
        final currentLeft = _currentSizes![leftIndex];
        final currentRight = _currentSizes![rightIndex];
        final newLeft = (currentLeft + delta).clamp(leftPane.minSize, leftPane.maxSize);
        final actualDelta = newLeft - currentLeft;
        final newRight = (currentRight - actualDelta).clamp(rightPane.minSize, rightPane.maxSize);

        _currentSizes![leftIndex] = currentLeft + (currentRight - newRight);
        _currentSizes![rightIndex] = newRight;
      }
    });

    widget.onSizesChanged?.call(List.unmodifiable(_currentSizes!));
  }

  void _onDoubleTapDivider(int dividerIndex, double totalAvailable) {
    setState(() {
      _initializeSizes(totalAvailable);
    });
    widget.onSizesChanged?.call(List.unmodifiable(_currentSizes!));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalConstraint = widget.direction == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;

        final effectiveBreakpoint = widget.responsiveBreakpoint ??
            (widget.direction == Axis.horizontal ? (widget.panes.length > 2 ? 880.0 : 640.0) : 480.0);

        if (totalConstraint < effectiveBreakpoint) {
          if (widget.responsiveStackedBuilder != null) {
            return widget.responsiveStackedBuilder!(
              context,
              widget.panes.map((p) => p.child).toList(),
            );
          }
          return SingleChildScrollView(
            scrollDirection: widget.direction == Axis.horizontal ? Axis.vertical : Axis.vertical,
            child: Flex(
              direction: Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.panes.map((p) => p.child).toList(),
            ),
          );
        }

        if (_currentSizes == null || (_lastTotalConstraint - totalConstraint).abs() > 2.0) {
          _initializeSizes(totalConstraint);
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

        final children = <Widget>[];

        for (int i = 0; i < widget.panes.length; i++) {
          final pane = widget.panes[i];
          final size = _currentSizes![i];

          // 1. Pane Content (Flexible panes use Expanded to prevent any subpixel overflows)
          if (pane.isFlexible) {
            children.add(
              Expanded(
                child: ClipRect(
                  child: pane.child,
                ),
              ),
            );
          } else {
            children.add(
              SizedBox(
                width: widget.direction == Axis.horizontal ? size : null,
                height: widget.direction == Axis.vertical ? size : null,
                child: ClipRect(
                  child: pane.child,
                ),
              ),
            );
          }

          // 2. Divider between adjacent panes
          if (i < widget.panes.length - 1) {
            final dividerIndex = i;
            final isDragging = _activeDraggingDividerIndex == dividerIndex;
            final isHovered = _hoveredDividerIndex == dividerIndex;

            children.add(
              MouseRegion(
                cursor: widget.direction == Axis.horizontal
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.resizeRow,
                onEnter: (_) => setState(() => _hoveredDividerIndex = dividerIndex),
                onExit: (_) => setState(() => _hoveredDividerIndex = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => _onDoubleTapDivider(dividerIndex, totalConstraint),
                  onHorizontalDragStart: widget.direction == Axis.horizontal
                      ? (_) => setState(() => _activeDraggingDividerIndex = dividerIndex)
                      : null,
                  onHorizontalDragUpdate: widget.direction == Axis.horizontal
                      ? (details) => _onDragUpdate(dividerIndex, details.delta.dx, totalConstraint)
                      : null,
                  onHorizontalDragEnd: widget.direction == Axis.horizontal
                      ? (_) => setState(() => _activeDraggingDividerIndex = null)
                      : null,
                  onVerticalDragStart: widget.direction == Axis.vertical
                      ? (_) => setState(() => _activeDraggingDividerIndex = dividerIndex)
                      : null,
                  onVerticalDragUpdate: widget.direction == Axis.vertical
                      ? (details) => _onDragUpdate(dividerIndex, details.delta.dy, totalConstraint)
                      : null,
                  onVerticalDragEnd: widget.direction == Axis.vertical
                      ? (_) => setState(() => _activeDraggingDividerIndex = null)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: widget.direction == Axis.horizontal ? widget.hitAreaThickness : double.infinity,
                    height: widget.direction == Axis.vertical ? widget.hitAreaThickness : double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base Line
                          Container(
                            width: widget.direction == Axis.horizontal
                                ? (isDragging ? 2.5 : (isHovered ? 2.0 : widget.dividerThickness))
                                : double.infinity,
                            height: widget.direction == Axis.vertical
                                ? (isDragging ? 2.5 : (isHovered ? 2.0 : widget.dividerThickness))
                                : double.infinity,
                            decoration: BoxDecoration(
                              color: isDragging || isHovered ? primaryColor : borderColor,
                              boxShadow: isDragging || isHovered
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),

                          // Visual Center Drag Grip Pill
                          if (isHovered || isDragging)
                            Container(
                              width: widget.direction == Axis.horizontal ? 8 : 28,
                              height: widget.direction == Axis.horizontal ? 28 : 8,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  widget.direction == Axis.horizontal
                                      ? Icons.drag_indicator_rounded
                                      : Icons.drag_handle_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Flex(
          direction: widget.direction,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
