import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A modern "Liquid Glass" style single-select dropdown.
class GlassSingleSelectDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final String value;
  final Function(String?)? onChanged;
  final Map<String, String>? displayMap;
  final bool dense;
  final double minWidth;
  final Color? iconColor;
  final double horizontalPadding;
  final double? width;
  final bool isExpanded;
  final double height;

  const GlassSingleSelectDropdown({
    Key? key,
    required this.label,
    required this.items,
    required this.value,
    this.onChanged,
    this.displayMap,
    this.dense = false,
    this.minWidth = 140,
    this.iconColor,
    this.horizontalPadding = 12,
    this.width,
    this.isExpanded = true,
    this.height = 42,
  }) : super(key: key);

  @override
  State<GlassSingleSelectDropdown> createState() =>
      _GlassSingleSelectDropdownState();
}

class _GlassSingleSelectDropdownState extends State<GlassSingleSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (widget.onChanged == null) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown() {
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final renderObject = context.findRenderObject();
    if (renderObject == null || !mounted) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }
    final RenderBox renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    final colorScheme = Theme.of(context).colorScheme;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final double itemHeight = widget.dense ? 38.0 : 46.0;
    final double menuHeight = widget.items.length * itemHeight + 12.0;
    const double maxMenuHeight = 350.0;
    final double estimatedHeight = menuHeight > maxMenuHeight
        ? maxMenuHeight
        : menuHeight;

    final spaceBelow = screenSize.height - position.dy - size.height;
    final spaceAbove = position.dy;
    final bool showAbove =
        spaceBelow < estimatedHeight && spaceAbove > spaceBelow;

    final targetAnchor = showAbove ? Alignment.topLeft : Alignment.bottomLeft;
    final followerAnchor = showAbove ? Alignment.bottomLeft : Alignment.topLeft;
    final offset = showAbove ? const Offset(0, -4) : const Offset(0, 4);
    final scaleAlignment = showAbove
        ? Alignment.bottomCenter
        : Alignment.topCenter;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: offset,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.95 + 0.05 * val,
                      alignment: scaleAlignment,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: size.width < widget.minWidth
                        ? widget.minWidth
                        : size.width,
                    constraints: const BoxConstraints(maxHeight: 350),
                    decoration: BoxDecoration(
                      color: colorScheme.headerBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.borderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.items.map((item) {
                          final isSelected = item == widget.value;
                          final label = widget.displayMap != null
                              ? (widget.displayMap![item] ?? item)
                              : item;
                          return HoverableSingleSelectOption(
                            label: label,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            dense: widget.dense,
                            onTap: () {
                              if (widget.onChanged != null) {
                                widget.onChanged!(item);
                              }
                              _closeDropdown();
                            },
                          );
                        }).toList(),
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = widget.displayMap != null
        ? (widget.displayMap![widget.value] ?? widget.value)
        : widget.value;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          InkWell(
            onTap: widget.onChanged == null ? null : _toggleDropdown,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: widget.height,
              width:
                  widget.width ?? (widget.isExpanded ? double.infinity : null),
              constraints: BoxConstraints(
                minWidth: widget.width ?? widget.minWidth,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: (widget.width != null || widget.isExpanded)
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.onChanged == null
                            ? colorScheme.subtitleText
                            : colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: widget.iconColor ?? colorScheme.subtitleText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HoverableSingleSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool dense;

  const HoverableSingleSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    this.dense = false,
  }) : super(key: key);

  @override
  State<HoverableSingleSelectOption> createState() =>
      _HoverableSingleSelectOptionState();
}

class _HoverableSingleSelectOptionState
    extends State<HoverableSingleSelectOption> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: widget.dense ? 6 : 10,
          ),
          margin: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: widget.dense ? 1 : 2,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.15)
                : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.4)
                  : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.25)
                        : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (widget.label == '新增課表') ...[
                Icon(Icons.add_rounded, size: 16, color: cs.accentBlue),
                const SizedBox(width: 8),
              ] else if (widget.label == '管理課表') ...[
                Icon(Icons.settings_outlined, size: 16, color: cs.subtitleText),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : (widget.label == '新增課表'
                              ? cs.accentBlue
                              : (widget.label == '管理課表'
                                    ? cs.subtitleText
                                    : cs.primaryText)),
                    fontWeight:
                        isSelected ||
                            widget.label == '新增課表' ||
                            widget.label == '管理課表'
                        ? FontWeight.bold
                        : FontWeight.w500,
                    fontSize: widget.dense ? 13 : 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: cs.accentBlue),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modern "Liquid Glass" style multi-select dropdown with checkboxes.
class GlassMultiSelectDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final Set<String> selectedValues;
  final Function(Set<String>)? onChanged;
  final Map<String, String>? displayMap;
  final bool dense;
  final double minWidth;
  final Color? iconColor;
  final double horizontalPadding;
  final String Function(String)? displayLabelFormatter;
  final double? width;
  final bool isExpanded;

  const GlassMultiSelectDropdown({
    Key? key,
    required this.label,
    required this.items,
    required this.selectedValues,
    this.onChanged,
    this.displayMap,
    this.dense = false,
    this.minWidth = 140,
    this.iconColor,
    this.horizontalPadding = 12,
    this.displayLabelFormatter,
    this.width,
    this.isExpanded = true,
  }) : super(key: key);

  @override
  State<GlassMultiSelectDropdown> createState() =>
      _GlassMultiSelectDropdownState();
}

class _GlassMultiSelectDropdownState extends State<GlassMultiSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  Set<String> _currentSelected = {};

  @override
  void initState() {
    super.initState();
    _currentSelected = Set<String>.from(widget.selectedValues);
  }

  @override
  void didUpdateWidget(covariant GlassMultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Use setEquality to avoid false positives from reference comparison
    if (!_setEquals(widget.selectedValues, oldWidget.selectedValues)) {
      _currentSelected = Set<String>.from(widget.selectedValues);
    }
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (widget.onChanged == null) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _currentSelected = Set<String>.from(widget.selectedValues);
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown() {
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  String _getDisplayLabel(String item) {
    if (widget.displayLabelFormatter != null) {
      return widget.displayLabelFormatter!(item);
    }
    return widget.displayMap != null
        ? (widget.displayMap![item] ?? item)
        : item;
  }

  OverlayEntry _createOverlayEntry() {
    final renderObject = context.findRenderObject();
    if (renderObject == null || !mounted) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }
    final RenderBox renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    final colorScheme = Theme.of(context).colorScheme;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final double itemHeight = widget.dense ? 38.0 : 46.0;
    final double menuHeight = widget.items.length * itemHeight + 12.0;
    const double maxMenuHeight = 300.0;
    final double estimatedHeight = menuHeight > maxMenuHeight
        ? maxMenuHeight
        : menuHeight;

    final spaceBelow = screenSize.height - position.dy - size.height;
    final spaceAbove = position.dy;
    final bool showAbove =
        spaceBelow < estimatedHeight && spaceAbove > spaceBelow;

    final targetAnchor = showAbove ? Alignment.topLeft : Alignment.bottomLeft;
    final followerAnchor = showAbove ? Alignment.bottomLeft : Alignment.topLeft;
    final offset = showAbove ? const Offset(0, -4) : const Offset(0, 4);
    final scaleAlignment = showAbove
        ? Alignment.bottomCenter
        : Alignment.topCenter;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: offset,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.95 + 0.05 * val,
                      alignment: scaleAlignment,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: size.width < widget.minWidth
                        ? widget.minWidth
                        : size.width,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: colorScheme.headerBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.borderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.items.map((item) {
                          final isSelected = _currentSelected.contains(item);
                          final label = _getDisplayLabel(item);
                          return HoverableMultiSelectOption(
                            label: label,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            dense: widget.dense,
                            onTap: () {
                              if (isSelected) {
                                _currentSelected.remove(item);
                              } else {
                                _currentSelected.add(item);
                              }
                              widget.onChanged?.call(
                                Set<String>.from(_currentSelected),
                              );
                              _overlayEntry?.markNeedsBuild();
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCount = _currentSelected.length;
    final displayValue = selectedCount == 0
        ? widget.label
        : (selectedCount <= 3
              ? _currentSelected.map(_getDisplayLabel).join(', ')
              : '$selectedCount 項已選');

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          InkWell(
            onTap: widget.onChanged == null ? null : _toggleDropdown,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              width:
                  widget.width ?? (widget.isExpanded ? double.infinity : null),
              constraints: BoxConstraints(
                minWidth: widget.width ?? widget.minWidth,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: (widget.width != null || widget.isExpanded)
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedCount == 0
                            ? colorScheme.subtitleText
                            : colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: widget.iconColor ?? colorScheme.subtitleText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HoverableMultiSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool dense;

  const HoverableMultiSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    this.dense = false,
  }) : super(key: key);

  @override
  State<HoverableMultiSelectOption> createState() =>
      _HoverableMultiSelectOptionState();
}

class _HoverableMultiSelectOptionState
    extends State<HoverableMultiSelectOption> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: widget.dense ? 6 : 10,
          ),
          margin: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: widget.dense ? 1 : 2,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.15)
                : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.4)
                  : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.25)
                        : Colors.transparent),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => widget.onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: cs.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                    fontSize: widget.dense ? 13 : 14,
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
