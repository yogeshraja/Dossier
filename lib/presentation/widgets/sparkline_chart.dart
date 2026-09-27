import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SparklinePoint {
  final String label;
  final double value;
  final int count;
  final String? extraInfo;

  const SparklinePoint({
    required this.label,
    required this.value,
    this.count = 0,
    this.extraInfo,
  });
}

class SparklineChart extends StatefulWidget {
  final List<SparklinePoint> points;
  final double height;
  final Color? lineColor;
  final Color? gradientStartColor;
  final Color? gradientEndColor;
  final double lineWidth;
  final bool showDots;
  final bool showBaseline;
  final String Function(double value)? valueFormatter;
  final String currencySymbol;

  const SparklineChart({
    super.key,
    required this.points,
    this.height = 120,
    this.lineColor,
    this.gradientStartColor,
    this.gradientEndColor,
    this.lineWidth = 2.5,
    this.showDots = true,
    this.showBaseline = true,
    this.valueFormatter,
    this.currencySymbol = '₹',
  });

  @override
  State<SparklineChart> createState() => _SparklineChartState();
}

class _SparklineChartState extends State<SparklineChart> {
  int? _hoveredIndex;
  Offset? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final lineColor = widget.lineColor ?? (isDark ? const Color(0xFF818CF8) : primary);
    final gradStart = widget.gradientStartColor ?? lineColor.withValues(alpha: 0.35);
    final gradEnd = widget.gradientEndColor ?? lineColor.withValues(alpha: 0.0);

    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No sales traffic data for this period',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    final peakPoint = widget.points.reduce((a, b) => a.value > b.value ? a : b);
    final totalSum = widget.points.fold<double>(0.0, (sum, p) => sum + p.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Micro Chart Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ssid_chart_rounded, size: 18, color: lineColor),
                const SizedBox(width: 8),
                Text(
                  'HOURLY REGISTER FLOW',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Peak: ${widget.currencySymbol}${peakPoint.value.toStringAsFixed(0)} (${peakPoint.label})',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: lineColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Vol: ${widget.currencySymbol}${totalSum.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Interactive Canvas Container
        MouseRegion(
          onHover: (event) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final localPos = event.localPosition;
            final width = box.size.width;
            final count = widget.points.length;
            if (count <= 1) return;

            final index = ((localPos.dx / width) * (count - 1)).round().clamp(0, count - 1);
            setState(() {
              _hoveredIndex = index;
              _hoverPosition = localPos;
            });
          },
          onExit: (_) {
            setState(() {
              _hoveredIndex = null;
              _hoverPosition = null;
            });
          },
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(double.infinity, widget.height),
                  painter: _SparklinePainter(
                    points: widget.points,
                    lineColor: lineColor,
                    gradientStartColor: gradStart,
                    gradientEndColor: gradEnd,
                    lineWidth: widget.lineWidth,
                    showDots: widget.showDots,
                    showBaseline: widget.showBaseline,
                    hoveredIndex: _hoveredIndex,
                    isDark: isDark,
                  ),
                ),

                // Interactive Hover Tooltip Pill
                if (_hoveredIndex != null && _hoveredIndex! < widget.points.length) ...[
                  _buildHoverTooltip(
                    point: widget.points[_hoveredIndex!],
                    isDark: isDark,
                    lineColor: lineColor,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // X-Axis Hour Markers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.points.first.label,
              style: GoogleFonts.spaceMono(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            if (widget.points.length > 2)
              Text(
                widget.points[widget.points.length ~/ 2].label,
                style: GoogleFonts.spaceMono(
                  fontSize: 9.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            Text(
              widget.points.last.label,
              style: GoogleFonts.spaceMono(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHoverTooltip({
    required SparklinePoint point,
    required bool isDark,
    required Color lineColor,
  }) {
    return Positioned(
      top: 4,
      left: _hoverPosition != null ? (_hoverPosition!.dx - 55).clamp(8.0, 220.0) : 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: lineColor.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              point.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.currencySymbol}${point.value.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (point.count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${point.count} txns)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: lineColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<SparklinePoint> points;
  final Color lineColor;
  final Color gradientStartColor;
  final Color gradientEndColor;
  final double lineWidth;
  final bool showDots;
  final bool showBaseline;
  final int? hoveredIndex;
  final bool isDark;

  _SparklinePainter({
    required this.points,
    required this.lineColor,
    required this.gradientStartColor,
    required this.gradientEndColor,
    required this.lineWidth,
    required this.showDots,
    required this.showBaseline,
    required this.hoveredIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double padding = 8.0;
    final double drawHeight = size.height - (padding * 2);
    final double drawWidth = size.width;

    double maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    double minValue = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);

    if (maxValue == minValue) {
      maxValue += 10.0;
      minValue = 0.0;
    }

    final double range = maxValue - minValue;
    final List<Offset> offsets = [];

    for (int i = 0; i < points.length; i++) {
      final double x = (i / (points.length - 1)) * drawWidth;
      final double normalizedY = (points[i].value - minValue) / range;
      final double y = size.height - padding - (normalizedY * drawHeight);
      offsets.add(Offset(x, y));
    }

    // Baseline grid rule
    if (showBaseline) {
      final basePaint = Paint()
        ..color = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(0, size.height - padding),
        Offset(size.width, size.height - padding),
        basePaint,
      );

      // Midline dashed grid
      final midY = size.height - padding - (drawHeight * 0.5);
      canvas.drawLine(
        Offset(0, midY),
        Offset(size.width, midY),
        basePaint,
      );
    }

    // Smooth Bezier Curve Path
    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Fill Gradient Path under curve
    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, size.height - padding)
      ..lineTo(offsets.first.dx, size.height - padding)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, padding),
        Offset(0, size.height - padding),
        [gradientStartColor, gradientEndColor],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Path
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Hover Scrub Line & Point Highlighting
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < offsets.length) {
      final activeOffset = offsets[hoveredIndex!];

      // Vertical scrub line
      final scrubPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(activeOffset.dx, padding),
        Offset(activeOffset.dx, size.height - padding),
        scrubPaint,
      );

      // Outer glow circle
      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(activeOffset, 8.0, glowPaint);

      // Inner dot
      final dotPaint = Paint()
        ..color = isDark ? Colors.white : const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(activeOffset, 4.0, dotPaint);

      final dotBorderPaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(activeOffset, 4.0, dotBorderPaint);
    } else if (showDots && offsets.isNotEmpty) {
      // Draw peak dot and latest dot
      int peakIdx = 0;
      for (int i = 1; i < points.length; i++) {
        if (points[i].value > points[peakIdx].value) peakIdx = i;
      }

      final peakOffset = offsets[peakIdx];
      final peakDotPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(peakOffset, 3.5, peakDotPaint);

      final lastOffset = offsets.last;
      final lastDotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(lastOffset, 3.5, lastDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isDark != isDark;
  }
}
