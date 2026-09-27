import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CaseStageDefinition {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const CaseStageDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class CaseStageTimeline extends StatelessWidget {
  final String currentStage;
  final ValueChanged<String>? onStageChanged;
  final int totalRequiredDocs;
  final int uploadedDocsCount;
  final bool isCompact;

  static const List<CaseStageDefinition> allStages = [
    CaseStageDefinition(
      key: 'DRAFT',
      label: 'Intake',
      description: 'Initial client inquiry & details gathered',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
    CaseStageDefinition(
      key: 'DOCS_PENDING',
      label: 'Docs Needed',
      description: 'Awaiting customer physical/digital documents',
      icon: Icons.pending_actions_rounded,
      color: Color(0xFFF59E0B), // Amber
    ),
    CaseStageDefinition(
      key: 'READY_TO_APPLY',
      label: 'Ready to Apply',
      description: 'All documents verified; ready for portal submission',
      icon: Icons.verified_user_rounded,
      color: Color(0xFF06B6D4), // Cyan
    ),
    CaseStageDefinition(
      key: 'SUBMITTED',
      label: 'Submitted',
      description: 'Application lodged on government portal',
      icon: Icons.send_rounded,
      color: Color(0xFF8B5CF6), // Violet
    ),
    CaseStageDefinition(
      key: 'READY_FOR_PICKUP',
      label: 'Ready for Pickup',
      description: 'Document / certificate ready for counter collection',
      icon: Icons.inventory_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    CaseStageDefinition(
      key: 'CLOSED',
      label: 'Completed',
      description: 'Delivered to customer & balance settled',
      icon: Icons.task_alt_rounded,
      color: Color(0xFF64748B), // Slate
    ),
  ];

  const CaseStageTimeline({
    super.key,
    required this.currentStage,
    this.onStageChanged,
    this.totalRequiredDocs = 0,
    this.uploadedDocsCount = 0,
    this.isCompact = false,
  });

  int get _currentIndex {
    final idx = allStages.indexWhere((s) => s.key == currentStage.toUpperCase());
    return idx != -1 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final docPercent = totalRequiredDocs > 0
        ? (uploadedDocsCount / totalRequiredDocs).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row with Doc Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.timeline_rounded, size: 16, color: primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIFECYCLE & STAGE PROGRESS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (totalRequiredDocs > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: docPercent == 1.0
                        ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: docPercent == 1.0
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        docPercent == 1.0 ? Icons.check_circle_rounded : Icons.folder_open_rounded,
                        size: 13,
                        color: docPercent == 1.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Docs: $uploadedDocsCount/$totalRequiredDocs (${(docPercent * 100).toStringAsFixed(0)}%)',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: docPercent == 1.0
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                              : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Horizontal Stepper Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(allStages.length, (index) {
                final stage = allStages[index];
                final isPassed = index < _currentIndex;
                final isCurrent = index == _currentIndex;
                final isFuture = index > _currentIndex;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Step Node
                    _buildStepNode(
                      stage: stage,
                      isPassed: isPassed,
                      isCurrent: isCurrent,
                      isFuture: isFuture,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),

                    // Connector Line (if not last)
                    if (index < allStages.length - 1)
                      _buildConnector(
                        isPassed: isPassed,
                        isDark: isDark,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required CaseStageDefinition stage,
    required bool isPassed,
    required bool isCurrent,
    required bool isFuture,
    required bool isDark,
    required Color primaryColor,
  }) {
    Color nodeBg;
    Color nodeBorder;
    Color iconColor;
    Color labelColor;

    if (isPassed) {
      nodeBg = const Color(0xFF10B981);
      nodeBorder = const Color(0xFF10B981);
      iconColor = Colors.white;
      labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    } else if (isCurrent) {
      nodeBg = stage.color;
      nodeBorder = stage.color;
      iconColor = Colors.white;
      labelColor = isDark ? Colors.white : const Color(0xFF0F172A);
    } else {
      nodeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      nodeBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
      iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      labelColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }

    return MouseRegion(
      cursor: onStageChanged != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onStageChanged != null ? () => onStageChanged!(stage.key) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isCurrent)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stage.color.withValues(alpha: 0.25),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: nodeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeBorder, width: isCurrent ? 2 : 1),
                    boxShadow: [
                      if (isCurrent)
                        BoxShadow(
                          color: stage.color.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPassed ? Icons.check_rounded : stage.icon,
                      size: isPassed ? 15 : 13,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stage.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector({
    required bool isPassed,
    required bool isDark,
  }) {
    return Container(
      width: 28,
      height: 2.5,
      margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isPassed
            ? const Color(0xFF10B981)
            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
