import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple/Pinterest-like segmented tabs (Media / History / Events)
/// API is unchanged: currentIndex, onChanged, counts, compact.
class GlassSegmentedTabs extends StatefulWidget {
  const GlassSegmentedTabs({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.mediaCount,
    required this.historyCount,
    required this.eventsCount,
    this.compact = false,
  });

  final int currentIndex; // 0: Media, 1: History, 2: Events
  final ValueChanged<int> onChanged;
  final int mediaCount;
  final int historyCount;
  final int eventsCount;
  final bool compact;

  @override
  State<GlassSegmentedTabs> createState() => _GlassSegmentedTabsState();
}

class _GlassSegmentedTabsState extends State<GlassSegmentedTabs> {
  int _hovered = -1;
  int _pressed = -1;

  // Keyboard navigation --------------------------------------------------------
  void _activate(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onChanged(index.clamp(0, 2));
  }

  void _next() => _activate((widget.currentIndex + 1) % 3);
  void _prev() => _activate((widget.currentIndex - 1) < 0 ? 2 : widget.currentIndex - 1);
  void _first() => _activate(0);
  void _last() => _activate(2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final radius = 14.0;
    final bg = [
      scheme.surface.withValues(alpha: 0.75),
      scheme.surfaceContainerHighest.withValues(alpha: 0.90),
    ];

    final thumbMs = reduceMotion ? 120 : 220;
    final scaleMs = reduceMotion ? 80 : 110;

    return Semantics(
      label: 'Sections',
      container: true,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const _MoveRightIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _MoveLeftIntent(),
            LogicalKeySet(LogicalKeyboardKey.home): const _MoveHomeIntent(),
            LogicalKeySet(LogicalKeyboardKey.end): const _MoveEndIntent(),
            LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _MoveRightIntent: CallbackAction<_MoveRightIntent>(onInvoke: (_) => _next()),
              _MoveLeftIntent: CallbackAction<_MoveLeftIntent>(onInvoke: (_) => _prev()),
              _MoveHomeIntent: CallbackAction<_MoveHomeIntent>(onInvoke: (_) => _first()),
              _MoveEndIntent: CallbackAction<_MoveEndIntent>(onInvoke: (_) => _last()),
              ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                _activate(widget.currentIndex); // re-announce selection
                return null;
              }),
            },
            child: Focus(
              canRequestFocus: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Avoid NaN/Infinity
                      final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
                      final itemW = (w / 3).clamp(64.0, double.infinity);

                      return Stack(
                        children: [
                          // Animated thumb behind the selected item
                          AnimatedPositioned(
                            duration: Duration(milliseconds: thumbMs),
                            curve: Curves.easeOutCubic,
                            left: widget.currentIndex * itemW,
                            top: 0,
                            bottom: 0,
                            width: itemW,
                            child: _Thumb(compact: widget.compact, reduceMotion: reduceMotion),
                          ),

                          Row(
                            children: [
                              _Item(
                                index: 0,
                                width: itemW,
                                icon: Icons.movie_filter_outlined,
                                selectedIcon: Icons.movie_filter_rounded,
                                label: 'Media',
                                count: widget.mediaCount,
                                selected: widget.currentIndex == 0,
                                hovered: _hovered == 0,
                                pressed: _pressed == 0,
                                compact: widget.compact,
                                scaleMs: scaleMs,
                                onHover: (h) => setState(() => _hovered = h ? 0 : -1),
                                onTapDown: () => setState(() => _pressed = 0),
                                onTapCancel: () => setState(() => _pressed = -1),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _pressed = -1);
                                  _activate(0);
                                },
                              ),
                              _Item(
                                index: 1,
                                width: itemW,
                                icon: Icons.history_toggle_off,
                                selectedIcon: Icons.history_rounded,
                                label: 'History',
                                count: widget.historyCount,
                                selected: widget.currentIndex == 1,
                                hovered: _hovered == 1,
                                pressed: _pressed == 1,
                                compact: widget.compact,
                                scaleMs: scaleMs,
                                onHover: (h) => setState(() => _hovered = h ? 1 : -1),
                                onTapDown: () => setState(() => _pressed = 1),
                                onTapCancel: () => setState(() => _pressed = -1),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _pressed = -1);
                                  _activate(1);
                                },
                              ),
                              _Item(
                                index: 2,
                                width: itemW,
                                icon: Icons.bolt_outlined,
                                selectedIcon: Icons.bolt_rounded,
                                label: 'Events',
                                count: widget.eventsCount,
                                selected: widget.currentIndex == 2,
                                hovered: _hovered == 2,
                                pressed: _pressed == 2,
                                compact: widget.compact,
                                scaleMs: scaleMs,
                                onHover: (h) => setState(() => _hovered = h ? 2 : -1),
                                onTapDown: () => setState(() => _pressed = 2),
                                onTapCancel: () => setState(() => _pressed = -1),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _pressed = -1);
                                  _activate(2);
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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

// === Intents for keyboard nav =================================================
class _MoveRightIntent extends Intent {
  const _MoveRightIntent();
}

class _MoveLeftIntent extends Intent {
  const _MoveLeftIntent();
}

class _MoveHomeIntent extends Intent {
  const _MoveHomeIntent();
}

class _MoveEndIntent extends Intent {
  const _MoveEndIntent();
}

// === Parts ===================================================================

class _Thumb extends StatelessWidget {
  const _Thumb({required this.compact, required this.reduceMotion});
  final bool compact;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 120 : 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.primary.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.10),
            blurRadius: compact ? 10 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 2), // small top/bottom inset
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.index,
    required this.width,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.count,
    required this.selected,
    required this.hovered,
    required this.pressed,
    required this.compact,
    required this.scaleMs,
    required this.onHover,
    required this.onTapDown,
    required this.onTapCancel,
    required this.onTap,
  });

  final int index;
  final double width;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int count;
  final bool selected;
  final bool hovered;
  final bool pressed;
  final bool compact;
  final int scaleMs;
  final ValueChanged<bool> onHover;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconColor = selected
        ? scheme.primary.withValues(alpha: 0.95)
        : scheme.onSurfaceVariant.withValues(alpha: hovered ? 0.9 : 0.75);

    final textColor = scheme.onSurface.withValues(alpha: selected ? 0.92 : (hovered ? 0.80 : 0.72));

    final padV = compact ? 6.0 : 8.0;
    final padH = compact ? 8.0 : 10.0;
    final iconSize = compact ? 16.0 : 18.0;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label tab, ${_countText(count)}',
        child: SizedBox(
          width: width,
          child: Focus(
            canRequestFocus: true,
            skipTraversal: false,
            child: GestureDetector(
              onTapDown: (_) => onTapDown(),
              onTapCancel: onTapCancel,
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                duration: Duration(milliseconds: scaleMs),
                curve: Curves.easeOut,
                scale: pressed ? 0.98 : 1.0,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selected ? selectedIcon : icon, size: iconSize, color: iconColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.0,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountPill(count: count, selected: selected, compact: compact),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _countText(int n) => n > 99 ? '99 plus' : '$n';
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.selected, required this.compact});
  final int count;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Hide zero in compact mode to save space
    if (compact && count == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.20)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.60);

    final fg = selected
        ? scheme.onPrimaryContainer.withValues(alpha: 0.95)
        : scheme.onSurface.withValues(alpha: 0.70);

    final display = count > 99 ? '99+' : '$count';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        display,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
