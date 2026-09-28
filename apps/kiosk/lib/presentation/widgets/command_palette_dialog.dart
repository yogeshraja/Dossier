import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';

enum CommandCategory {
  navigation,
  posAction,
  dossier,
  caseItem,
  system,
}

class CommandItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final CommandCategory category;
  final List<String> keywords;
  final VoidCallback onSelect;

  const CommandItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.category,
    this.keywords = const [],
    required this.onSelect,
  });
}

class CommandPaletteDialog extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const CommandPaletteDialog({
    super.key,
    this.onNavigateTab,
  });

  static Future<void> show(BuildContext context, {void Function(int tabIndex)? onNavigateTab}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => CommandPaletteDialog(onNavigateTab: onNavigateTab),
    );
  }

  @override
  ConsumerState<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  String _query = '';

  List<Dossier> _allDossiers = [];
  List<Case> _allCases = [];
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadAsyncData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadAsyncData() async {
    try {
      final db = ref.read(databaseProvider);
      final dossiers = await db.select(db.dossiers).get();
      final cases = await db.select(db.cases).get();
      if (mounted) {
        setState(() {
          _allDossiers = dossiers;
          _allCases = cases;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<CommandItem> _buildCommands() {
    final List<CommandItem> items = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- Navigation Commands ---
    items.add(CommandItem(
      id: 'nav_dossiers',
      title: 'Go to Dossiers & Case Intake',
      subtitle: 'Customer files, document intake and live case tracking',
      icon: Icons.people_alt_rounded,
      iconColor: const Color(0xFF6366F1),
      category: CommandCategory.navigation,
      keywords: ['customer', 'dossier', 'intake', 'cases', 'clients', 'home'],
      onSelect: () {
        widget.onNavigateTab?.call(0);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'nav_media',
      title: 'Go to Media Studio',
      subtitle: 'ID card stitcher, passport photo grid & image compression',
      icon: Icons.burst_mode_rounded,
      iconColor: const Color(0xFF06B6D4),
      category: CommandCategory.navigation,
      keywords: ['media', 'photo', 'stitch', 'passport', 'id card', 'crop', 'camera'],
      onSelect: () {
        widget.onNavigateTab?.call(1);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'nav_pos',
      title: 'Go to Quick POS & Billing',
      subtitle: 'Instant counter billing, itemized invoices & thermal prints',
      icon: Icons.point_of_sale_rounded,
      iconColor: const Color(0xFF10B981),
      category: CommandCategory.navigation,
      keywords: ['pos', 'billing', 'invoice', 'sale', 'cash', 'receipt', 'upi'],
      onSelect: () {
        widget.onNavigateTab?.call(2);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'nav_register',
      title: 'Go to Daily Sales Register',
      subtitle: 'Daily turnover, hourly traffic, payment breakdown & EOD closure',
      icon: Icons.analytics_rounded,
      iconColor: const Color(0xFFF59E0B),
      category: CommandCategory.navigation,
      keywords: ['register', 'sales', 'daily', 'eod', 'closure', 'reconciliation', 'report'],
      onSelect: () {
        widget.onNavigateTab?.call(3);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'nav_sync',
      title: 'Go to Cloud Vault Sync (Settings)',
      subtitle: 'Google Drive & Cloudflare R2 backup status and outbox queue',
      icon: Icons.cloud_sync_rounded,
      iconColor: const Color(0xFF8B5CF6),
      category: CommandCategory.navigation,
      keywords: ['sync', 'cloud', 'vault', 'backup', 'drive', 'r2', 'queue', 'settings'],
      onSelect: () {
        widget.onNavigateTab?.call(4);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'nav_settings',
      title: 'Go to Settings & Profile Hub',
      subtitle: 'Service catalog pricing, cloud vault sync, printer setup and kiosk preferences',
      icon: Icons.tune_rounded,
      iconColor: const Color(0xFFEC4899),
      category: CommandCategory.navigation,
      keywords: ['settings', 'config', 'printer', 'prices', 'catalog', 'services', 'vault'],
      onSelect: () {
        widget.onNavigateTab?.call(4);
        Navigator.of(context).pop();
      },
    ));

    // --- POS Quick Actions ---
    items.add(CommandItem(
      id: 'action_new_sale',
      title: 'Create Quick POS Sale',
      subtitle: 'Open fast register counter to ring up walk-in customer items',
      icon: Icons.add_shopping_cart_rounded,
      iconColor: const Color(0xFF10B981),
      category: CommandCategory.posAction,
      keywords: ['new sale', 'add bill', 'walk-in', 'charge', 'quick pos'],
      onSelect: () {
        widget.onNavigateTab?.call(2);
        Navigator.of(context).pop();
      },
    ));

    items.add(CommandItem(
      id: 'action_new_dossier',
      title: 'Create New Customer Dossier',
      subtitle: 'Register new client profile with Aadhaar/PAN and contact info',
      icon: Icons.person_add_alt_1_rounded,
      iconColor: const Color(0xFF6366F1),
      category: CommandCategory.posAction,
      keywords: ['new customer', 'new client', 'create dossier', 'add user'],
      onSelect: () {
        widget.onNavigateTab?.call(0);
        Navigator.of(context).pop();
      },
    ));

    // --- System Actions ---
    items.add(CommandItem(
      id: 'system_toggle_theme',
      title: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
      subtitle: 'Toggle between sleek dark slate and crisp light mode',
      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
      category: CommandCategory.system,
      keywords: ['theme', 'dark mode', 'light mode', 'color', 'night'],
      onSelect: () {
        ref.read(kioskSettingsProvider.notifier).toggleTheme();
        Navigator.of(context).pop();
      },
    ));

    // --- Dynamic Customer Dossiers ---
    for (final d in _allDossiers) {
      items.add(CommandItem(
        id: 'dossier_${d.id}',
        title: d.fullName,
        subtitle: 'Phone: ${d.phoneNumber} ${d.email != null ? "• ${d.email}" : ""}',
        icon: Icons.folder_shared_rounded,
        iconColor: const Color(0xFF6366F1),
        category: CommandCategory.dossier,
        keywords: [d.fullName.toLowerCase(), d.phoneNumber, if (d.email != null) d.email!.toLowerCase(), 'customer', 'dossier'],
        onSelect: () {
          ref.read(activeDossierIdProvider.notifier).state = d.id;
          widget.onNavigateTab?.call(0);
          Navigator.of(context).pop();
        },
      ));
    }

    // --- Dynamic Cases ---
    for (final c in _allCases) {
      items.add(CommandItem(
        id: 'case_${c.id}',
        title: c.title,
        subtitle: 'Stage: ${c.stage} • Fee: ₹${c.totalEstimatedAmount.toStringAsFixed(0)} • Status: ${c.paymentStatus}',
        icon: Icons.assignment_outlined,
        iconColor: const Color(0xFF06B6D4),
        category: CommandCategory.caseItem,
        keywords: [c.title.toLowerCase(), c.stage.toLowerCase(), c.paymentStatus.toLowerCase(), 'case', 'application'],
        onSelect: () {
          ref.read(activeCaseIdProvider.notifier).state = c.id;
          widget.onNavigateTab?.call(0);
          Navigator.of(context).pop();
        },
      ));
    }

    // Filter by query
    if (_query.trim().isEmpty) {
      return items;
    }

    final q = _query.trim().toLowerCase();
    return items.where((item) {
      if (item.title.toLowerCase().contains(q)) return true;
      if (item.subtitle != null && item.subtitle!.toLowerCase().contains(q)) return true;
      if (item.keywords.any((k) => k.contains(q))) return true;
      return false;
    }).toList();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final commands = _buildCommands();
    if (commands.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % commands.length;
      });
      _scrollToIndex(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + commands.length) % commands.length;
      });
      _scrollToIndex(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < commands.length) {
        commands[_selectedIndex].onSelect();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 60.0;
    final targetOffset = (index * itemHeight) - 120.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  String _getCategoryLabel(CommandCategory cat) {
    switch (cat) {
      case CommandCategory.navigation:
        return 'Navigation';
      case CommandCategory.posAction:
        return 'Quick POS & Workflows';
      case CommandCategory.dossier:
        return 'Customer Dossiers';
      case CommandCategory.caseItem:
        return 'Active Cases & Services';
      case CommandCategory.system:
        return 'System & Themes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commands = _buildCommands();
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_selectedIndex >= commands.length) {
      _selectedIndex = commands.isNotEmpty ? 0 : 0;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 640,
            maxHeight: 560,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a command, customer name, case, or route...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            fillColor: Colors.transparent,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _query = val;
                              _selectedIndex = 0;
                            });
                          },
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _selectedIndex = 0;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'ESC',
                          style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Command List
                Expanded(
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : commands.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No results found for "$_query"',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: commands.length,
                              itemBuilder: (context, index) {
                                final item = commands[index];
                                final isSelected = index == _selectedIndex;

                                return _CommandItemTile(
                                  item: item,
                                  isSelected: isSelected,
                                  categoryLabel: _getCategoryLabel(item.category),
                                  onTap: item.onSelect,
                                  onHover: () => setState(() => _selectedIndex = index),
                                );
                              },
                            ),
                ),

                // Keyboard Shortcuts Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildKeyBadge('↑ ↓', 'Navigate', isDark),
                          const SizedBox(width: 14),
                          _buildKeyBadge('↵ Enter', 'Select', isDark),
                          const SizedBox(width: 14),
                          _buildKeyBadge('ESC', 'Close', isDark),
                        ],
                      ),
                      Text(
                        '${commands.length} actions available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyBadge(String keyText, String actionText, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              width: 0.6,
            ),
          ),
          child: Text(
            keyText,
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          actionText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _CommandItemTile extends StatelessWidget {
  final CommandItem item;
  final bool isSelected;
  final String categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandItemTile({
    required this.item,
    required this.isSelected,
    required this.categoryLabel,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final tileBg = isSelected
        ? (isDark ? primaryColor.withValues(alpha: 0.18) : primaryColor.withValues(alpha: 0.08))
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (item.iconColor ?? primaryColor).withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.iconColor ?? primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoryLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_return_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
