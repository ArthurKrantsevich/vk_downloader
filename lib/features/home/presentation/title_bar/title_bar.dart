import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowState { normal, maximized }

class TitleBar extends StatefulWidget {
  const TitleBar({super.key});

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  WindowState _windowState = WindowState.normal;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeWindowState();
  }

  Future<void> _initializeWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    setState(() {
      _windowState = isMaximized ? WindowState.maximized : WindowState.normal;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    Future.delayed(const Duration(milliseconds: 50), () async {
      await windowManager.setMinimumSize(const Size(700.0, 700.0));
    });
    setState(() => _windowState = WindowState.maximized);
  }

  @override
  void onWindowUnmaximize() {
    Future.delayed(const Duration(milliseconds: 50), () async {
      await windowManager.setMinimumSize(const Size(700.0, 700.0));
    });
    setState(() => _windowState = WindowState.normal);
  }

  Future<void> _handleCloseAction(BuildContext context) async {
    exit(0);
  }

  Future<void> _toggleMaximize() async {
    bool isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Text(
                "Media Downloader",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onPanStart: (_) => windowManager.startDragging(),
                    onDoubleTap: _toggleMaximize,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
                _circleIconButton(
                  context,
                  icon: Icons.minimize_rounded,
                  tooltip: "Collapse",
                  onPressed: () => windowManager.minimize(),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _circleIconButton(
                    context,
                    icon: _windowState == WindowState.maximized
                        ? Icons.fullscreen_exit_outlined
                        : Icons.fullscreen_outlined,
                    tooltip: _windowState == WindowState.maximized
                        ? "Restore"
                        : "Maximize",
                    onPressed: _toggleMaximize,
                  ),
                ),
                _circleIconButton(
                  context,
                  icon: Icons.close_rounded,
                  tooltip: "Close app",
                  onPressed: () => _handleCloseAction(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
      BuildContext context, {
        required IconData icon,
        required String tooltip,
        required VoidCallback onPressed,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.75),
        ),
        splashRadius: 16,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: onPressed,
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(
            colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
