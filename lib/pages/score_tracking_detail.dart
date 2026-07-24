import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/score_item.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_dropdown.dart';
import '../services/offline_error_handler.dart';

class ScoreTrackingDetail extends StatefulWidget {
  final CourseScoreData courseData;
  final Future<void> Function() onRefresh;
  // 修正：onSave 改為接收最新 CourseScoreData
  final void Function(CourseScoreData) onSave;

  const ScoreTrackingDetail({
    Key? key,
    required this.courseData,
    required this.onRefresh,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ScoreTrackingDetail> createState() => _ScoreTrackingDetailState();
}

class _ScoreTrackingDetailState extends State<ScoreTrackingDetail> {
  bool _isEditing = false;
  final Map<String, TextEditingController> _textControllers = {};
  late CourseScoreData _courseData;

  // 本地擴展狀態（取代 Riverpod 的 scoreExpansionProvider）
  final Map<String, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _courseData = widget.courseData;

    // 若 targetGrade 未設定，給預設值 A+
    if (_courseData.targetGrade == null) {
      _courseData = _courseData.copyWith(targetGrade: 'A+');
      // 同步存檔，讓下次載入也有預設值
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSave(_courseData);
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScoreTrackingDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseData.courseId != widget.courseData.courseId) {
      _clearControllers();
      setState(() {
        _courseData = widget.courseData;
        _isEditing = false;
      });
    }
  }

  TextEditingController _getController(String key, String? initialText) {
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: initialText ?? '');
    } else if (!_textControllers[key]!.selection.isValid) {
      // 只有在非編輯狀態下才同步外部值（包含 null → 清空）
      _textControllers[key]!.text = initialText ?? '';
    }
    return _textControllers[key]!;
  }

  void _clearControllers() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
  }

  List<ScoreItem> _updateItemInList(
    List<ScoreItem> list,
    String id,
    ScoreItem Function(ScoreItem) updateFn,
  ) {
    return list.map((item) {
      if (item.id == id) {
        return updateFn(item);
      }
      if (item.hasChildren) {
        return item.copyWith(
          children: _updateItemInList(item.children, id, updateFn),
        );
      }
      return item;
    }).toList();
  }

  List<ScoreItem> _removeItemFromList(List<ScoreItem> list, String id) {
    final filtered = list.where((item) => item.id != id).toList();
    if (filtered.length < list.length) {
      return filtered;
    }
    return list.map((item) {
      if (item.hasChildren) {
        return item.copyWith(
          children: _removeItemFromList(item.children, id),
        );
      }
      return item;
    }).toList();
  }

  ScoreItem _balanceChildrenWeights(ScoreItem parent, String? changedChildId, double? newChildWeight) {
    if (parent.children.isEmpty) return parent;

    List<ScoreItem> newChildren = List.from(parent.children);

    if (changedChildId != null && newChildWeight != null) {
      int changedIdx = newChildren.indexWhere((c) => c.id == changedChildId);
      if (changedIdx != -1) {
        double cappedWeight = newChildWeight.clamp(0.0, parent.weight);
        newChildren[changedIdx] = newChildren[changedIdx].copyWith(weight: cappedWeight);
        
        double remainingWeight = parent.weight - cappedWeight;
        List<int> otherIndices = [];
        for (int i = 0; i < newChildren.length; i++) {
          if (i != changedIdx) otherIndices.add(i);
        }

        if (otherIndices.isNotEmpty) {
          double otherTotal = otherIndices.fold(0.0, (sum, idx) => sum + newChildren[idx].weight);
          if (otherTotal == 0) {
            double evenWeight = remainingWeight / otherIndices.length;
            for (int idx in otherIndices) {
              newChildren[idx] = newChildren[idx].copyWith(weight: evenWeight);
            }
          } else {
            for (int idx in otherIndices) {
              double proportion = newChildren[idx].weight / otherTotal;
              newChildren[idx] = newChildren[idx].copyWith(weight: remainingWeight * proportion);
            }
          }
        }
      }
    } else {
      double currentTotal = newChildren.fold(0.0, (sum, c) => sum + c.weight);
      if (currentTotal > 0) {
        for (int i = 0; i < newChildren.length; i++) {
          double proportion = newChildren[i].weight / currentTotal;
          newChildren[i] = newChildren[i].copyWith(weight: parent.weight * proportion);
        }
      } else {
        double evenWeight = parent.weight / newChildren.length;
        for (int i = 0; i < newChildren.length; i++) {
          newChildren[i] = newChildren[i].copyWith(weight: evenWeight);
        }
      }
    }

    double sum = 0;
    for (int i = 0; i < newChildren.length - 1; i++) {
      double rounded = double.parse(newChildren[i].weight.toStringAsFixed(2));
      newChildren[i] = newChildren[i].copyWith(weight: rounded);
      sum += rounded;
    }
    if (newChildren.isNotEmpty) {
      double lastWeight = double.parse((parent.weight - sum).toStringAsFixed(2));
      if (lastWeight < 0) lastWeight = 0;
      newChildren.last = newChildren.last.copyWith(weight: lastWeight);
    }

    return parent.copyWith(children: newChildren);
  }

  void _updateWeightWithAutoBalance(String itemId, double newWeight) {
    setState(() {
      List<ScoreItem> updatedList = _updateItemInList(
        _courseData.items,
        itemId,
        (i) => i.copyWith(weight: newWeight),
      );

      List<ScoreItem> balancedList = [];
      for (var parent in updatedList) {
        if (parent.hasChildren) {
          bool hasChangedChild = parent.children.any((c) => c.id == itemId);
          balancedList.add(_balanceChildrenWeights(
            parent, 
            hasChangedChild ? itemId : null, 
            hasChangedChild ? newWeight : null,
          ));
        } else {
          balancedList.add(parent);
        }
      }

      _courseData = _courseData.copyWith(items: balancedList);
    });
  }

  void _deleteItemWithAutoBalance(String itemId) {
    setState(() {
      List<ScoreItem> removedList = _removeItemFromList(_courseData.items, itemId);
      
      List<ScoreItem> balancedList = [];
      for (var parent in removedList) {
        if (parent.hasChildren) {
          balancedList.add(_balanceChildrenWeights(parent, null, null));
        } else {
          balancedList.add(parent);
        }
      }
      _courseData = _courseData.copyWith(items: balancedList);
    });
  }

  String _formatWeight(double weight) {
    String s = weight.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0*$'), '');
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void _enterEditMode() {
    _clearControllers();
    final preferredOrder = ['出席', '小考', '期中考', '期末考', '期中報告', '期末報告'];

    if (_courseData.items.isEmpty) {
      _courseData = _courseData.copyWith(
        items: preferredOrder
            .map((name) => ScoreItem.fromRawData(name, 0))
            .toList(),
        isCustomized: true,
      );
      widget.onSave(_courseData);
    } else {
      final sorted = List<ScoreItem>.from(_courseData.items);
      sorted.sort((a, b) {
        int indexA = preferredOrder.indexOf(a.name);
        int indexB = preferredOrder.indexOf(b.name);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
      _courseData = _courseData.copyWith(items: sorted);
    }

    setState(() {
      _isEditing = true;
    });
  }

  void _exitEditMode() {
    _clearControllers();
    setState(() {
      _isEditing = false;
      _courseData = widget.courseData;
    });
  }

  void _saveEditMode() {
    double totalWeight = _courseData.items.fold(
      0,
      (sum, item) => sum + item.weight,
    );
    if ((totalWeight - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("權重總和必須為 100%，目前為 ${totalWeight.toStringAsFixed(2)}%"),
          duration: const Duration(seconds: 2),),
      );
      return;
    }

    _courseData = _courseData.copyWith(
      isCustomized: true,
      lastUpdated: DateTime.now(),
    );

    _clearControllers();
    setState(() {
      _isEditing = false;
    });

    widget.onSave(_courseData);
  }

  Future<void> _handleRefresh() async {
    if (await OfflineErrorHandler.handleRefresh(context)) return;
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        // refresh 後同步 widget 傳入的最新資料
        _courseData = widget.courseData;
        _isEditing = false;
      });
      _clearControllers();
    }
  }

  bool _areWeightsEvenlyDistributed(List<ScoreItem> children) {
    if (children.length <= 1) return true;
    final firstWeight = children.first.weight;
    for (final child in children.skip(1)) {
      if ((child.weight - firstWeight).abs() > 0.01) return false;
    }
    return true;
  }

  // 修正：回傳更新後的 parent，並寫回 _courseData
  ScoreItem _addChildItem(ScoreItem parent) {
    final children = List<ScoreItem>.from(parent.children);
    String newName;
    double newWeight;

    if (children.isEmpty) {
      final childWeight = double.parse((parent.weight / 2).toStringAsFixed(2));
      children.add(ScoreItem.fromRawData('${parent.name} 1', childWeight));
      newName = '${parent.name} 2';
      newWeight = double.parse(
        (parent.weight - childWeight).toStringAsFixed(2),
      );
    } else if (_areWeightsEvenlyDistributed(children)) {
      final newCount = children.length + 1;
      final baseWeight = double.parse(
        (parent.weight / newCount).toStringAsFixed(2),
      );
      double total = 0;
      for (int i = 0; i < children.length; i++) {
        children[i] = children[i].copyWith(weight: baseWeight);
        total += baseWeight;
      }
      newName = '${parent.name} $newCount';
      newWeight = double.parse((parent.weight - total).toStringAsFixed(2));
    } else {
      newName = '${parent.name} ${children.length + 1}';
      newWeight = 0;
    }

    children.add(ScoreItem.fromRawData(newName, newWeight));
    // 使用本地狀態取代 Riverpod
    setState(() {
      _expandedItems[parent.id] = true;
    });

    final updatedParent = parent.copyWith(children: children, clearScore: true);
    final balancedParent = _balanceChildrenWeights(updatedParent, null, null);

    // 修正：使用遞迴更新寫回 _courseData
    _courseData = _courseData.copyWith(
      items: _updateItemInList(
        _courseData.items,
        parent.id,
        (item) => balancedParent,
      ),
    );

    return updatedParent;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 預估分析
          _buildPredictionAnalysis(),

          const SizedBox(height: 16),

          // 目標等第選擇
          _buildTargetGradeSelector(),

          const SizedBox(height: 16),

          // 標題列
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "評分方式",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.subtitleText,
                ),
              ),
              Row(
                children: [
                  if (_courseData.isCustomized)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        "自訂",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _handleRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: "重新抓取配分方式",
                    color: colorScheme.accentBlue,
                  ),
                  IconButton(
                    onPressed: _enterEditMode,
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: "編輯配分",
                    color: colorScheme.accentBlue,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 配分項目列表
          if (_isEditing) _buildEditableScoreItems() else _buildScoreItems(),
        ],
      ),
    );
  }

  Widget _buildScoreItems() {
    return Column(
      children: _courseData.items.map((item) {
        return _buildScoreItemRow(item);
      }).toList(),
    );
  }

  Widget _buildScoreItemRow(ScoreItem item, {int level = 0}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final controllerKey = '${_courseData.courseId}_${item.id}';
    final controller = _getController(
      controllerKey,
      item.score
              ?.toStringAsFixed(2)
              .replaceAll(RegExp(r'0*$'), '')
              .replaceAll(RegExp(r'\.$'), '') ??
          '',
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: level * 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  "${item.name} (${_formatWeight(item.weight)}%)",
                  style: TextStyle(
                    fontSize: 14 - level * 1,
                    color: colorScheme.primaryText,
                    fontWeight: level == 0
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                ),
              ),

              if (!item.hasChildren)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "未輸入",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: colorScheme.subtitleText.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isLiquidGlass
                              ? (colorScheme.isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.3))
                              : colorScheme.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isLiquidGlass
                              ? (colorScheme.isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.3))
                              : colorScheme.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.accentBlue,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: isLiquidGlass
                          ? (colorScheme.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.3))
                          : colorScheme.cardBackground,
                      isDense: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d{0,3}(\.\d{0,2})?$'),
                      ),
                    ],
                    onChanged: (value) {
                      final score = value.trim().isEmpty
                          ? null
                          : double.tryParse(value);

                      setState(() {
                        _courseData = _courseData.copyWith(
                          items: _updateItemInList(
                            _courseData.items,
                            item.id,
                            (i) => i.copyWith(score: score, clearScore: score == null),
                          ),
                        );
                      });
                      widget.onSave(_courseData);
                    },
                  ),
                )
              else
                const SizedBox(width: 120),

              const SizedBox(width: 8),

              if (level == 0 && item.children.length < 5)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _addChildItem(item);
                    });
                    widget.onSave(_courseData);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: "新增子項目",
                  color: colorScheme.accentBlue,
                )
              else if (level == 0)
                const SizedBox(width: 40),
            ],
          ),

          if (item.hasChildren) ...[
            const SizedBox(height: 4),
            ...item.children.map((child) {
              return _buildScoreItemRow(child, level: level + 1);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableScoreItems() {
    return Column(
      children: [
        ..._courseData.items.asMap().entries.map((entry) {
          return _buildEditableScoreItemRow(_courseData.items, entry.key, 0);
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  final newItems = List<ScoreItem>.from(_courseData.items)
                    ..add(ScoreItem.fromRawData('新項目', 0));
                  _courseData = _courseData.copyWith(items: newItems);
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text("新增項目"),
            ),
            const Spacer(),
            TextButton(onPressed: _exitEditMode, child: const Text("取消")),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveEditMode, child: const Text("完成編輯")),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableScoreItemRow(
    List<ScoreItem> list,
    int index,
    int level,
  ) {
    final item = list[index];
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: level * 20.0),
      child: Container(
        decoration: isLiquidGlass
            ? glassCardDecoration(context, borderRadius: 10)
            : BoxDecoration(
                color: colorScheme.secondaryCardBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor, width: 0.8),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _getController('${item.id}_name', item.name),
                    onChanged: (value) {
                      setState(() {
                        _courseData = _courseData.copyWith(
                          items: _updateItemInList(
                            _courseData.items,
                            item.id,
                            (i) => i.copyWith(name: value),
                          ),
                        );
                      });
                    },
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: "項目名稱",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isLiquidGlass
                          ? (colorScheme.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.3))
                          : colorScheme.cardBackground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _getController(
                      '${item.id}_weight',
                      _formatWeight(item.weight),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.primaryText,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}(\.\d{0,2})?$'),
                      ),
                    ],
                    onChanged: (value) {
                      final newWeight = value.trim().isEmpty
                          ? 0.0
                          : (double.tryParse(value) ?? 0.0);
                      _updateWeightWithAutoBalance(item.id, newWeight);
                    },

                    decoration: InputDecoration(
                      suffixText: "%",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isLiquidGlass
                          ? (colorScheme.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.3))
                          : colorScheme.cardBackground,
                    ),
                  ),
                ),
                if (level == 0 && item.children.length < 5)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _addChildItem(item);
                      });
                    },
                    icon: const Icon(Icons.add, size: 20),
                    color: colorScheme.accentBlue,
                    tooltip: "新增子項目",
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  )
                else if (level == 0)
                  const SizedBox(width: 28),
                IconButton(
                  onPressed: () {
                    _deleteItemWithAutoBalance(item.id);
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.redAccent,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (item.children.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...item.children.asMap().entries.map((childEntry) {
                return _buildEditableScoreItemRow(
                  item.children,
                  childEntry.key,
                  level + 1,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTargetGradeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final grades = [
      'A+',
      'A',
      'A-',
      'B+',
      'B',
      'B-',
      'C+',
      'C',
      'C-',
      'D',
      'E',
      'F',
    ];

    return Row(
      children: [
        Text(
          "目標等第：",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.subtitleText,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: GlassSingleSelectDropdown(
            label: "",
            items: grades,
            value: _courseData.targetGrade ?? 'A+',
            dense: true,
            onChanged: (value) {
              setState(() {
                _courseData = _courseData.copyWith(targetGrade: value);
              });
              widget.onSave(_courseData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionAnalysis() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTotal = _courseData.currentTotal;
    final enteredWeight = _courseData.enteredWeight;
    final remainingWeight = 100 - enteredWeight;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    double? targetMinScore;
    if (_courseData.targetGrade != null) {
      targetMinScore = _getGradeMinScore(_courseData.targetGrade!);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 8)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.borderColor),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "預估分析",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.subtitleText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (currentTotal != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "目前總分",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.subtitleText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${currentTotal.toStringAsFixed(1)} / 100",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.subtitleText.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "已輸入權重",
                style: TextStyle(fontSize: 12, color: colorScheme.subtitleText),
              ),
              const SizedBox(width: 8),
              Text(
                "${enteredWeight.toStringAsFixed(2)}%",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          if (targetMinScore != null && remainingWeight > 0) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final needed = targetMinScore! - (currentTotal ?? 0);
                final avgNeeded = needed / (remainingWeight / 100);
                final isUnreachable = avgNeeded > 100;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUnreachable
                        ? Colors.red.withValues(alpha: 0.1)
                        : colorScheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _calculateNeededText(targetMinScore),
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnreachable
                          ? Colors.redAccent
                          : colorScheme.accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ] else if (targetMinScore != null && remainingWeight <= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                currentTotal != null && currentTotal >= targetMinScore
                    ? "目前已達成目標！"
                    : "目前總分 ${currentTotal?.toStringAsFixed(1)} 未達目標 ${targetMinScore.toStringAsFixed(0)} 分",
                style: TextStyle(
                  fontSize: 13,
                  color: currentTotal != null && currentTotal >= targetMinScore
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculateNeededText(double targetMinScore) {
    final currentTotal = _courseData.currentTotal ?? 0;
    final remainingWeight = 100 - _courseData.enteredWeight;

    if (remainingWeight <= 0) return "所有項目已輸入完成";

    final needed = targetMinScore - currentTotal;
    final avgNeeded = needed / (remainingWeight / 100);

    if (avgNeeded <= 0) {
      return "目前已達成目標！";
    }

    return "剩餘項目平均需要：${avgNeeded.toStringAsFixed(1)} 分（目標 ${_courseData.targetGrade}，需達 ${targetMinScore.toStringAsFixed(0)} 分）";
  }

  double _getGradeMinScore(String grade) {
    switch (grade) {
      case 'A+':
        return 90;
      case 'A':
        return 85;
      case 'A-':
        return 80;
      case 'B+':
        return 77;
      case 'B':
        return 73;
      case 'B-':
        return 70;
      case 'C+':
        return 67;
      case 'C':
        return 63;
      case 'C-':
        return 60;
      case 'D':
        return 50;
      case 'E':
        return 40;
      case 'F':
        return 0;
      default:
        return 0;
    }
  }
}