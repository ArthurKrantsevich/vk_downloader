import 'dart:ui';
import 'package:flutter/material.dart';
import '../../application/home_state.dart';

class CompactSearchBar extends StatelessWidget {
  const CompactSearchBar({
    super.key,
    required this.state,
    required this.urlController,
    required this.onOpenUrl,
    required this.onBack,
    required this.onScan,
  });

  final HomeState state;
  final TextEditingController urlController;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onBack;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Frosted top capsule
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
            bottom: Radius.zero,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                  bottom: Radius.zero,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface.withValues(alpha: 0.70),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back
                  _GlassIconButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 8),

                  // URL / Search field
                  Expanded(
                    child: _UrlCapsule(
                      controller: urlController,
                      hintText: 'Search Google or paste a link',
                      onSubmit: onOpenUrl,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Scan
                  _GlassPillButton(
                    tooltip: 'Scan media on page',
                    icon: Icons.photo_library_outlined,
                    label: compact ? null : 'Scan',
                    emphasis: PillEmphasis.accent,
                    onTap: onScan,
                  ),
                ],
              ),
            ),
          ),
        ),

      ],
    );
  }
}

/* ======================
 *  Apple/Pinterest UI
 * ====================== */

enum PillEmphasis { primary, accent, neutral }

class _GlassPillButton extends StatefulWidget {
  const _GlassPillButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.label,
    this.emphasis = PillEmphasis.neutral,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final PillEmphasis emphasis;

  @override
  State<_GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<_GlassPillButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;

    Color base;
    Color border;
    Color fg;

    switch (widget.emphasis) {
      case PillEmphasis.primary:
        base = scheme.primary.withValues(alpha: 0.14);
        border = scheme.primary.withValues(alpha: 0.28);
        fg = scheme.primary;
        break;
      case PillEmphasis.accent:
        base = scheme.tertiary.withValues(alpha: 0.12);
        border = scheme.tertiary.withValues(alpha: 0.26);
        fg = scheme.tertiary;
        break;
      case PillEmphasis.neutral:
      base = scheme.surface.withValues(alpha: 0.58);
        border = scheme.outlineVariant.withValues(alpha: 0.32);
        fg = scheme.onSurface.withValues(alpha: 0.86);
    }

    final bg = _pressed
        ? base.withValues(alpha: base.a + 0.10)
        : _hover
        ? base.withValues(alpha: base.a + 0.06)
        : base;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: hasLabel ? 12 : 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: 1),
              boxShadow: _hover
                  ? [
                BoxShadow(
                  color: fg.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: fg),
                if (hasLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: 0.2,
                    ),
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

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final base = scheme.surface.withValues(alpha: 0.60);
    final hover = scheme.surface.withValues(alpha: 0.72);
    final press = scheme.surface.withValues(alpha: 0.82);
    final bg = _pressed ? press : (_hover ? hover : base);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.86)),
          ),
        ),
      ),
    );
  }
}

class _UrlCapsule extends StatefulWidget {
  const _UrlCapsule({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hintText;
  final Future<void> Function(String url) onSubmit;

  @override
  State<_UrlCapsule> createState() => _UrlCapsuleState();
}

class _UrlCapsuleState extends State<_UrlCapsule> {
  late final FocusNode _focusNode;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'CompactSearchUrlField');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    if (widget.controller.text.isEmpty) return;
    widget.controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _focusNode.hasFocus;

    final bg = scheme.surface.withValues(alpha: 0.78);
    final borderColor = focused
        ? scheme.primary.withValues(alpha: 0.45)
        : scheme.outlineVariant.withValues(alpha: _hover ? 0.45 : 0.35);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: focused ? 1.2 : 1),
          boxShadow: focused
              ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onSubmitted: widget.onSubmit,
                textInputAction: TextInputAction.go,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: widget.controller.text.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 120),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _clear,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

