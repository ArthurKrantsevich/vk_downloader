import 'package:flutter/material.dart';
import '../../../../core/widgets/unified_button.dart';
import '../../domain/browser_tab.dart';

/// Compact tab bar for browser tabs (max 5 tabs)
class BrowserTabBar extends StatelessWidget {
  const BrowserTabBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
    required this.canAddTab,
  });

  final List<BrowserTab> tabs;
  final String activeTabId;
  final void Function(String tabId) onTabSelected;
  final void Function(String tabId) onTabClosed;
  final VoidCallback onNewTab;
  final bool canAddTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.8)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tabs
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = tab.id == activeTabId;

                return _TabItem(
                  tab: tab,
                  isActive: isActive,
                  onTap: () => onTabSelected(tab.id),
                  onClose: tabs.length > 1 ? () => onTabClosed(tab.id) : null,
                  scheme: scheme,
                  isDark: isDark,
                );
              },
            ),
          ),

          // New tab button
          const SizedBox(width: 8),
          UnifiedButton(
            icon: Icons.add,
            onTap: canAddTab ? onNewTab : null,
            tooltip: canAddTab ? 'New tab (max 5)' : 'Maximum 5 tabs reached',
            size: ButtonSize.small,
            variant: ButtonVariant.neutral,
            enabled: canAddTab,
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.scheme,
    required this.isDark,
  });

  final BrowserTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final ColorScheme scheme;
  final bool isDark;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          constraints: const BoxConstraints(
            minWidth: 130,
            maxWidth: 220,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            // Much stronger background contrast for active tab
            gradient: widget.isActive
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.scheme.primaryContainer.withValues(alpha: 0.4),
                      widget.scheme.surface,
                    ],
                  )
                : null,
            color: widget.isActive
                ? null
                : (_isHovered
                    ? widget.scheme.surfaceContainerHigh.withValues(alpha: 0.8)
                    : Colors.transparent),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
            // Enhanced border for active tab
            border: widget.isActive
                ? Border(
                    top: BorderSide(
                      color: widget.scheme.primary,
                      width: 3,
                    ),
                    left: BorderSide(
                      color: widget.scheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    right: BorderSide(
                      color: widget.scheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  )
                : Border(
                    top: BorderSide(
                      color: _isHovered
                          ? widget.scheme.outline.withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
            // Shadow for active tab
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.scheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Favicon with stronger color for active tab
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? widget.scheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.public,
                  size: 15,
                  color: widget.isActive
                      ? widget.scheme.primary
                      : widget.scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),

              // Tab title with better contrast
              Expanded(
                child: Text(
                  widget.tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: widget.isActive ? 0.2 : 0,
                    color: widget.isActive
                        ? widget.scheme.onSurface
                        : widget.scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),

              // Close button (show on hover or if active)
              if (_isHovered || widget.isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: widget.isActive
                              ? widget.scheme.primary.withValues(alpha: 0.15)
                              : widget.scheme.onSurface.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: widget.isActive
                              ? widget.scheme.primary
                              : widget.scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

