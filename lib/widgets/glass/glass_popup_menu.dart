import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass_decoration.dart';

/// 一個彈出選單項目。
class GlassPopupMenuItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;

  /// 是否在這個項目之前繪製一條分隔線。
  final bool dividerBefore;

  const GlassPopupMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
    this.dividerBefore = false,
  });
}

/// Liquid Glass 風格的彈出選單。
///
/// 在 liquid glass 模式下以 overlay 呈現「半透明玻璃 + 背景模糊」的選單，
/// 視覺與 [GlassSingleSelectDropdown] 的下拉選單一致；非玻璃模式則退回
/// 標準 [PopupMenuButton] 外觀（呼叫端負責分支，確保其他模式樣式不變）。
class GlassPopupMenu<T> extends StatefulWidget {
  final Widget child;
  final List<GlassPopupMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final double menuWidth;

  const GlassPopupMenu({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
    this.menuWidth = 220,
  });

  @override
  State<GlassPopupMenu<T>> createState() => _GlassPopupMenuState<T>();
}

class _GlassPopupMenuState<T> extends State<GlassPopupMenu<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() {
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final colorScheme = Theme.of(context).colorScheme;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 6),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.95 + 0.05 * val,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: widget.menuWidth,
                    decoration: glassMenuDecoration(context),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.items.map((item) {
                        return _GlassPopupOption<T>(
                          item: item,
                          colorScheme: colorScheme,
                          onTap: () {
                            widget.onSelected(item.value);
                            _closeMenu();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _openMenu,
        borderRadius: BorderRadius.circular(8),
        child: widget.child,
      ),
    );
  }
}

class _GlassPopupOption<T> extends StatefulWidget {
  final GlassPopupMenuItem<T> item;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _GlassPopupOption({
    required this.item,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  State<_GlassPopupOption<T>> createState() => _GlassPopupOptionState<T>();
}

class _GlassPopupOptionState<T> extends State<_GlassPopupOption<T>> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final item = widget.item;
    final accent = cs.accentBlue;

    final Widget option = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 玻璃模式：按下即觸發，不必等放開（GlassPopupMenu 僅用於 liquid glass 模式）。
        onTapDown: (_) => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _isHovering
                ? accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovering
                  ? accent.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 18,
                  color: item.isDestructive
                      ? Colors.red
                      : (item.iconColor ?? cs.primaryText),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.isDestructive
                        ? Colors.red
                        : cs.primaryText,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!item.dividerBefore) return option;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.borderColor.withValues(alpha: 0.4),
          ),
        ),
        option,
      ],
    );
  }
}
