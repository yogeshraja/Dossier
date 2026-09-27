import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';

class CollapsibleSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final KioskOperator? currentOperator;
  final VoidCallback onShowOperatorMenu;
  final VoidCallback onToggleTheme;
  final ThemeMode currentThemeMode;
  final bool isInitiallyCollapsed;

  const CollapsibleSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.currentOperator,
    required this.onShowOperatorMenu,
    required this.onToggleTheme,
    required this.currentThemeMode,
    this.isInitiallyCollapsed = false,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  late bool _isCollapsed;

  static const _navItems = [
    (
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'Dossiers & Intake',
      tooltip: 'Customer Dossiers & Case Intake',
    ),
    (
      icon: Icons.burst_mode_outlined,
      activeIcon: Icons.burst_mode_rounded,
      label: 'Media Studio',
      tooltip: 'ID Card Stitcher & Image Prep Studio',
    ),
    (
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
      label: 'POS & Billing',
      tooltip: 'Quick POS Register & Invoices',
    ),
    (
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics_rounded,
      label: 'Daily Register',
      tooltip: 'End-of-Day Register & Cash Reconciliation',
    ),
    (
      icon: Icons.cloud_sync_outlined,
      activeIcon: Icons.cloud_sync_rounded,
      label: 'Vault Sync',
      tooltip: 'Offline-First Cloud Vault & Sync Monitor',
    ),
    (
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
      label: 'Catalog & Settings',
      tooltip: 'Services Catalog, Pricing & Kiosk Config',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.isInitiallyCollapsed;
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).navigationRailTheme.backgroundColor ??
        (isDark ? const Color(0xFF0F172A) : Colors.white);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final sidebarWidth = _isCollapsed ? 76.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: ClipRect(
        child: SizedBox(
          width: sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8 : 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 20),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DOSSIER',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'KIOSK VAULT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  fontSize: 9,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (!_isCollapsed)
                      IconButton(
                        icon: const Icon(Icons.menu_open_rounded, size: 20),
                        tooltip: 'Collapse Sidebar',
                        onPressed: _toggleSidebar,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),

              if (_isCollapsed)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.menu_rounded, size: 20),
                      tooltip: 'Expand Sidebar',
                      onPressed: _toggleSidebar,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),

              // Nav Items
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 6 : 8, vertical: 12),
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    final item = _navItems[index];
                    final isSelected = widget.selectedIndex == index;

                    return _SidebarNavItem(
                      icon: isSelected ? item.activeIcon : item.icon,
                      label: item.label,
                      tooltip: item.tooltip,
                      isSelected: isSelected,
                      isCollapsed: _isCollapsed,
                      onTap: () => widget.onDestinationSelected(index),
                    );
                  },
                ),
              ),

              // Footer Section (Operator & Theme Mode)
              Container(
                padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 6 : 10, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.currentOperator != null)
                      _isCollapsed
                          ? Tooltip(
                              message: 'Operator: ${widget.currentOperator!.fullName} (${widget.currentOperator!.role.label})',
                              child: InkWell(
                                onTap: widget.onShowOperatorMenu,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: widget.currentOperator!.role.color,
                                    child: Text(
                                      widget.currentOperator!.initials,
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : InkWell(
                              onTap: widget.onShowOperatorMenu,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor, width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: widget.currentOperator!.role.color,
                                      child: Text(
                                        widget.currentOperator!.initials,
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.currentOperator!.fullName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            widget.currentOperator!.role.label,
                                            style: TextStyle(fontSize: 10, color: widget.currentOperator!.role.color, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.unfold_more_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                    const SizedBox(height: 8),

                    // Theme Mode Switcher
                    _isCollapsed
                        ? IconButton(
                            icon: Icon(
                              widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: 19,
                            ),
                            tooltip: widget.currentThemeMode == ThemeMode.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                            onPressed: widget.onToggleTheme,
                          )
                        : DossierButton(
                            text: widget.currentThemeMode == ThemeMode.dark ? 'Light Theme' : 'Dark Theme',
                            icon: widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: DossierButtonSize.sm,
                            variant: DossierButtonVariant.outline,
                            isFullWidth: true,
                            tooltip: 'Toggle between Dark and Light UI themes',
                            onPressed: widget.onToggleTheme,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    Color itemBgColor;
    Color itemFgColor;

    if (widget.isSelected) {
      itemBgColor = primaryColor.withValues(alpha: isDark ? 0.22 : 0.12);
      itemFgColor = isDark ? const Color(0xFF818CF8) : primaryColor;
    } else if (_isHovered) {
      itemBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      itemFgColor = isDark ? Colors.white : const Color(0xFF0F172A);
    } else {
      itemBgColor = Colors.transparent;
      itemFgColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 0 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: itemBgColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1)
                : null,
          ),
          child: ClipRect(
            child: Row(
              mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  width: widget.isCollapsed ? 48 : 24,
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: itemFgColor,
                    ),
                  ),
                ),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: itemFgColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isSelected) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: widget.isCollapsed
            ? Tooltip(
                message: widget.tooltip,
                waitDuration: const Duration(milliseconds: 200),
                child: content,
              )
            : content,
      ),
    );
  }
}

