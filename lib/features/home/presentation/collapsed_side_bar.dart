import 'dart:ui';
import 'package:flutter/material.dart';

class CollapsedSidebar extends StatefulWidget {
  const CollapsedSidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.mediaCount,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final int mediaCount;

  @override
  State<CollapsedSidebar> createState() => _CollapsedSidebarState();
}

class _CollapsedSidebarState extends State<CollapsedSidebar> with TickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start animations when media count changes
    if (widget.mediaCount > 0 && !widget.isExpanded) {
      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CollapsedSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaCount != oldWidget.mediaCount && widget.mediaCount > 0 && !widget.isExpanded) {
      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } else if (widget.isExpanded || widget.mediaCount == 0) {
      _pulseController.stop();
      _glowController.stop();
      _pulseController.reset();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _glowController]),
        builder: (context, child) {
          final scale = widget.mediaCount > 0 && !widget.isExpanded
              ? _pulseAnimation.value
              : (_isHovered ? 1.08 : 1.0);

          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 64,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    // Outer glow
                    if (widget.mediaCount > 0 && !widget.isExpanded)
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.4 * _glowController.value),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    // Main shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.15),
                      blurRadius: _isHovered ? 32 : 20,
                      offset: Offset(4, _isHovered ? 8 : 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isExpanded
                              ? [
                                  scheme.primaryContainer.withValues(alpha: 0.95),
                                  scheme.primary.withValues(alpha: 0.8),
                                ]
                              : [
                                  scheme.surface.withValues(alpha: 0.95),
                                  scheme.surfaceContainerHigh.withValues(alpha: 0.9),
                                ],
                        ),
                        border: Border.all(
                          color: widget.isExpanded
                              ? scheme.primary.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Shimmer effect on hover
                          if (_isHovered)
                            Positioned.fill(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.1),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Content
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Main icon with rotation
                                AnimatedRotation(
                                  turns: widget.isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOutCubicEmphasized,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.isExpanded
                                          ? scheme.primary.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                    ),
                                    child: Icon(
                                      widget.isExpanded
                                          ? Icons.chevron_left_rounded
                                          : Icons.layers_rounded,
                                      size: 28,
                                      color: widget.isExpanded
                                          ? scheme.onPrimaryContainer
                                          : scheme.primary,
                                    ),
                                  ),
                                ),

                                // Media count badge
                                if (widget.mediaCount > 0)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.isExpanded
                                          ? scheme.primary
                                          : scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      widget.mediaCount > 99 ? '99+' : '${widget.mediaCount}',
                                      style: TextStyle(
                                        color: widget.isExpanded
                                            ? scheme.onPrimary
                                            : scheme.onPrimaryContainer,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
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
              ),
            ),
          );
        },
      ),
    );
  }
}