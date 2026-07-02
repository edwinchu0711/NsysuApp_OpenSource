import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchableDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final bool enableSearch;

  const SearchableDropdownField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.suggestions,
    required this.onChanged,
    this.enableSearch = true,
  });

  @override
  State<SearchableDropdownField> createState() =>
      _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends State<SearchableDropdownField> {
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _filteredSuggestions = [];
  bool _isOpen = false;
  bool _isRemoving = false; // 添加標記防止重複移除

  @override
  void initState() {
    super.initState();
    // 初始化過濾建議列表，限制顯示前 30 項
    _filteredSuggestions = widget.suggestions.take(30).toList();

    // 如果啟用搜尋功能，添加搜尋監聽器
    if (widget.enableSearch) {
      _searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void deactivate() {
    // 頁面切換時立即清理，不要調用 setState
    // deactivate() 在 build 階段被調用，此時不能觸發 setState
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOpen = false;
      _isRemoving = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    // 確保在 dispose 時清理所有資源
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    // 移除搜尋監聽器
    if (widget.enableSearch) {
      _searchController.removeListener(_onSearchChanged);
    }

    // 釋放控制器和焦點節點
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 搜尋文字變化時的回調
  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        // 搜尋為空時，顯示前 30 項建議
        _filteredSuggestions = widget.suggestions.take(30).toList();
      } else {
        // 根據搜尋關鍵字過濾建議，限制顯示前 30 項
        _filteredSuggestions = widget.suggestions
            .where((s) => s.toLowerCase().contains(query))
            .take(30)
            .toList();
      }
    });
    // 更新 overlay 顯示
    _updateOverlay();
  }

  /// 切換下拉選單的開關狀態
  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  /// 顯示下拉選單 overlay
  void _showOverlay() {
    // 獲取輸入框的渲染物件以計算位置和大小
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    // 重置搜尋框和過濾列表
    _searchController.clear();
    _filteredSuggestions = widget.suggestions.take(30).toList();

    // 創建並插入 overlay
    _overlayEntry = _createOverlayEntry(size);
    Overlay.of(context).insert(_overlayEntry!);

    // 更新開啟狀態
    setState(() => _isOpen = true);

    // 如果啟用搜尋，自動聚焦到搜尋框
    if (widget.enableSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  /// 移除下拉選單 overlay（方案三：完全重構版本）
  void _removeOverlay() {
    // 防止重複調用
    if (_isRemoving) return;
    if (_overlayEntry == null) return; // 已經移除了

    _isRemoving = true;

    // 1. 先更新狀態變數（不觸發 rebuild）
    _isOpen = false;

    // 2. 保存 overlay 引用並清空
    final entry = _overlayEntry;
    _overlayEntry = null;

    // 3. 在下一幀安全地移除 overlay 和更新 UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 移除 overlay
      entry?.remove();

      // 重置移除標記
      _isRemoving = false;

      // 安全地觸發 UI 更新
      if (mounted) {
        setState(() {}); // 只是觸發 rebuild，狀態已經更新
      }
    });
  }

  /// 標記 overlay 需要重建
  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  /// 選擇下拉選單中的項目
  void _selectItem(String item) {
    // 1. 先更新 controller
    widget.controller.text = item;

    // 2. 立即調用 onChanged (在關閉 overlay 之前!)
    try {
      widget.onChanged(item);
    } catch (e) {
      debugPrint('SearchableDropdownField: onChanged error: $e');
    }

    // 3. 最後關閉下拉選單
    _removeOverlay();
  }

  /// 創建下拉選單的 overlay entry
  OverlayEntry _createOverlayEntry(Size fieldSize) {
    return OverlayEntry(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return GestureDetector(
          // 點擊外部區域關閉下拉選單
          behavior: HitTestBehavior.translucent,
          onTap: _removeOverlay,
          child: Stack(
            children: [
              Positioned(
                width: fieldSize.width,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: Offset(0, fieldSize.height + 4),
                  child: GestureDetector(
                    // 防止點擊下拉選單內部時關閉
                    onTap: () {},
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: colorScheme.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.borderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 搜尋框區域（如果啟用搜尋功能）
                            if (widget.enableSearch) ...[
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: '搜尋...',
                                    hintStyle: TextStyle(
                                      color: colorScheme.subtitleText,
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor:
                                        colorScheme.secondaryCardBackground,
                                    prefixIcon: Icon(
                                      Icons.search,
                                      size: 18,
                                      color: colorScheme.subtitleText,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colorScheme.borderColor,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colorScheme.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colorScheme.accentBlue,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.primaryText,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                            // 建議列表區域
                            Flexible(
                              child: _filteredSuggestions.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        '無符合結果',
                                        style: TextStyle(
                                          color: colorScheme.subtitleText,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: _filteredSuggestions.length,
                                      itemBuilder: (context, index) {
                                        final item =
                                            _filteredSuggestions[index];
                                        final isSelected =
                                            item == widget.controller.text;

                                        return InkWell(
                                          onTap: () {
                                            _selectItem(item);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 1,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? colorScheme.accentBlue
                                                        .withValues(alpha: 0.1)
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isSelected
                                                    ? colorScheme.accentBlue
                                                    : colorScheme.primaryText,
                                                fontWeight: isSelected
                                                    ? FontWeight.w400
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AbsorbPointer(
          child: TextField(
            key: _fieldKey,
            controller: widget.controller,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: colorScheme.subtitleText,
                fontSize: 14,
              ),
              filled: true,
              fillColor: colorScheme.secondaryCardBackground,
              suffixIcon: AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                  color: colorScheme.subtitleText,
                ),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _isOpen
                      ? colorScheme.accentBlue
                      : colorScheme.borderColor,
                  width: _isOpen ? 2 : 1,
                ),
              ),
            ),
            style: TextStyle(fontSize: 14, color: colorScheme.primaryText),
          ),
        ),
      ),
    );
  }
}