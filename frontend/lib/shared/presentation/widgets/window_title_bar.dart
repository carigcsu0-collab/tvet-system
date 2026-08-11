import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowTitleBar extends StatelessWidget {
  final String title;

  const WindowTitleBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final fg = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 32,
        color: bg,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Image.asset(
              'assets/app_icon.png',
              width: 16,
              height: 16,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 12, color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Minimize
            _WindowButton(
              icon: Icons.minimize,
              iconSize: 16,
              color: fg,
              bg: bg,
              onPressed: () => windowManager.minimize(),
            ),
            // Maximize/Restore
            _WindowButton(
              icon: Icons.crop_square,
              iconSize: 14,
              color: fg,
              bg: bg,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            // Close
            _WindowButton(
              icon: Icons.close,
              iconSize: 18,
              color: fg,
              bg: bg,
              hoverBg: const Color(0xFFE81123),
              hoverFg: Colors.white,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final Color bg;
  final Color? hoverBg;
  final Color? hoverFg;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.bg,
    this.hoverBg,
    this.hoverFg,
    required this.onPressed,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _hovering
              ? (widget.hoverBg ?? widget.bg.withValues(alpha: 0.1))
              : widget.bg,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hovering && widget.hoverFg != null
                ? widget.hoverFg
                : widget.color,
          ),
        ),
      ),
    );
  }
}
