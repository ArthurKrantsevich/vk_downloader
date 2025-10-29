import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/widgets/unified_button.dart';
import '../../application/home_state.dart';

class CompactSearchBar extends StatelessWidget {
  const CompactSearchBar({
    super.key,
    required this.state,
    required this.urlController,
    required this.onOpenUrl,
    required this.onBack,
  });

  final HomeState state;
  final TextEditingController urlController;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onBack;

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
            top: Radius.circular(12),
            bottom: Radius.zero,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                  bottom: Radius.zero,
                ),
                color: scheme.surface.withValues(alpha: 0.95),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back
                  UnifiedButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                    size: ButtonSize.small,
                    variant: ButtonVariant.neutral,
                  ),
                  const SizedBox(width: 6),

                  // URL / Search field
                  Expanded(
                    child: _UrlCapsule(
                      controller: urlController,
                      hintText: 'Search Google or paste a link',
                      onSubmit: onOpenUrl,
                    ),
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

    final bg = scheme.surface.withValues(alpha: 0.85);
    final borderColor = focused
        ? scheme.primary.withValues(alpha: 0.4)
        : scheme.outlineVariant.withValues(alpha: _hover ? 0.4 : 0.3);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: focused
              ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onSubmitted: widget.onSubmit,
                textInputAction: TextInputAction.go,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(top: 6, bottom: 6, left: 6),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: widget.controller.text.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 120),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _clear,
                child: const Padding(
                  padding: EdgeInsets.all(3.0),
                  child: Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

