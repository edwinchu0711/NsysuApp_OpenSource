import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/score_item.dart';
import '../theme/app_theme.dart';
import '../widgets/glass/glass_dropdown.dart';

/// 遷移映射資料
class MigrationMapping {
  String oldItemId;
  String? newItemId; // null 表示不遷移（捨棄）
  double? customScore; // 使用者自訂分數，null 表示使用系統計算值

  MigrationMapping({required this.oldItemId, this.newItemId, this.customScore});
}

/// 分數遷移助手對話框
class ScoreMigrationDialog extends StatefulWidget {
  final List<ScoreItem> oldItems;
  final List<ScoreItem> newItems;
  final String courseName;

  const ScoreMigrationDialog({
    Key? key,
    required this.oldItems,
    required this.newItems,
    required this.courseName,
  }) : super(key: key);

  @override
  State<ScoreMigrationDialog> createState() => _ScoreMigrationDialogState();
}

class _ScoreMigrationDialogState extends State<ScoreMigrationDialog> {
  late List<MigrationMapping> _mappings;
  final Map<String, TextEditingController> _customScoreControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeMappings();
  }

  void _initializeMappings() {
    _mappings = [];
    for (var oldItem in widget.oldItems) {
      // 嘗試自動匹配名稱相同的新項目
      String? matchedNewId;
      for (var newItem in widget.newItems) {
        if (newItem.name == oldItem.name) {
          matchedNewId = newItem.id;
          break;
        }
      }
      _mappings.add(
        MigrationMapping(oldItemId: oldItem.id, newItemId: matchedNewId),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _customScoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScoreItem? _findOldItem(String id) {
    try {
      return widget.oldItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 計算遷移後的分數
  double? _calculateMigratedScore(MigrationMapping mapping) {
    if (mapping.customScore != null) return mapping.customScore;

    final oldItem = _findOldItem(mapping.oldItemId);
    if (oldItem == null) return null;

    // 檢查是否為合併遷移（多個舊項目映射到同一個新項目）
    final mappingsToSameNew = _mappings
        .where((m) => m.newItemId == mapping.newItemId && m.newItemId != null)
        .toList();

    if (mappingsToSameNew.length > 1) {
      // 合併遷移：加權平均
      double totalScore = 0;
      double totalWeight = 0;
      for (var m in mappingsToSameNew) {
        final item = _findOldItem(m.oldItemId);
        if (item != null && item.effectiveScore != null) {
          totalScore += item.effectiveScore! * item.weight;
          totalWeight += item.weight;
        }
      }
      if (totalWeight <= 0) return null;
      return totalScore / totalWeight;
    }

    // 一對一遷移：原分數
    return oldItem.effectiveScore;
  }

  /// 取得某個新項目已被映射的舊項目清單
  List<MigrationMapping> _getMappingsForNewItem(String newItemId) {
    return _mappings.where((m) => m.newItemId == newItemId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Dialog(
      backgroundColor: colorScheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 1000 : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Row(
                children: [
                  Icon(Icons.sync_alt, color: colorScheme.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "分數遷移助手 - ${widget.courseName}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close),
                    color: colorScheme.subtitleText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "配分方式已更新。請選擇舊項目的分數要遷移到哪個新項目。",
                style: TextStyle(fontSize: 13, color: colorScheme.subtitleText),
              ),
              const SizedBox(height: 16),

              // 三欄內容
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildOldItemsColumn()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNewItemsColumn()),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildOldItemsColumn(),
                            const SizedBox(height: 16),
                            _buildNewItemsColumn(),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // 底部按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text("取消，保留舊配分"),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showPreview,
                    child: const Text("預覽結果"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _confirmMigration,
                    child: const Text("確認遷移"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOldItemsColumn() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "舊配分（待遷移）",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.primaryText,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.oldItems.length,
            itemBuilder: (context, index) {
              final item = widget.oldItems[index];
              final mapping = _mappings.firstWhere(
                (m) => m.oldItemId == item.id,
              );
              final hasScore = item.effectiveScore != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryCardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasScore
                        ? colorScheme.accentBlue.withValues(alpha: 0.3)
                        : colorScheme.borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${item.name} (${item.weight.toStringAsFixed(0)}%)",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primaryText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (hasScore)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${item.effectiveScore!.toStringAsFixed(1)} 分",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.hasChildren) ...[
                      const SizedBox(height: 4),
                      ...item.children
                          .map(
                            (child) => Padding(
                              padding: const EdgeInsets.only(left: 12, top: 2),
                              child: Text(
                                "  ${child.name}: ${child.effectiveScore?.toStringAsFixed(1) ?? '未輸入'}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.subtitleText,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ],
                    const SizedBox(height: 12),
                    GlassSingleSelectDropdown(
                      label: "遷移目標",
                      items: [
                        'discard',
                        ...widget.newItems.map((newItem) => newItem.id),
                      ],
                      value: mapping.newItemId ?? 'discard',
                      dense: true,
                      displayMap: {
                        'discard': "不遷移（捨棄）",
                        ...{
                          for (var newItem in widget.newItems)
                            newItem.id: "-> ${newItem.name}",
                        },
                      },
                      onChanged: (value) {
                        setState(() {
                          mapping.newItemId = (value == 'discard')
                              ? null
                              : value;
                          // 清除自訂分數
                          mapping.customScore = null;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewItemsColumn() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "新配分（目標）",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.primaryText,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.newItems.length,
            itemBuilder: (context, index) {
              final newItem = widget.newItems[index];
              final sourceMappings = _getMappingsForNewItem(newItem.id);
              final hasSource = sourceMappings.isNotEmpty;

              // 計算遷移後的分數
              double? migratedScore;
              if (hasSource) {
                migratedScore = _calculateMigratedScore(sourceMappings.first);
              }

              // 檢查是否為合併遷移
              final isMerged = sourceMappings.length > 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryCardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasSource
                        ? Colors.green.withValues(alpha: 0.3)
                        : colorScheme.borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${newItem.name} (${newItem.weight.toStringAsFixed(0)}%)",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primaryText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (hasSource)
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          )
                        else
                          Icon(
                            Icons.radio_button_unchecked,
                            color: colorScheme.subtitleText,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (!hasSource)
                      Text(
                        "未指定來源",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      )
                    else ...[
                      // 顯示來源
                      ...sourceMappings.map((m) {
                        final oldItem = _findOldItem(m.oldItemId);
                        return Text(
                          "<- ${oldItem?.name ?? '未知'} (${oldItem?.effectiveScore?.toStringAsFixed(1) ?? '未輸入'})",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.subtitleText,
                          ),
                        );
                      }),
                      if (isMerged)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "合併遷移（加權平均）",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // 分數顯示與自訂
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "遷移後分數：${migratedScore?.toStringAsFixed(1) ?? '未輸入'}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: migratedScore != null
                                    ? colorScheme.accentBlue
                                    : colorScheme.subtitleText,
                              ),
                            ),
                          ),
                          // 自訂分數按鈕
                          TextButton.icon(
                            onPressed: () => _showCustomScoreDialog(
                              sourceMappings.first,
                              migratedScore,
                            ),
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text("自訂"),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCustomScoreDialog(MigrationMapping mapping, double? currentScore) {
    final controller = TextEditingController(
      text:
          mapping.customScore?.toStringAsFixed(1) ??
          (currentScore?.toStringAsFixed(1) ?? ''),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("自訂分數"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("輸入您想要設定為此項目的分數"),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "分數",
                suffixText: "分",
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^-?\d{0,3}(\.\d?)?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "留空則使用系統計算值：${currentScore?.toStringAsFixed(1) ?? '未輸入'}",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.subtitleText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                mapping.customScore = null; // 清除自訂
              });
              Navigator.pop(ctx);
            },
            child: const Text("清除自訂"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              setState(() {
                mapping.customScore = val;
              });
              Navigator.pop(ctx);
            },
            child: const Text("確認"),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    final colorScheme = Theme.of(context).colorScheme;

    // 統計資訊
    int mappedCount = _mappings.where((m) => m.newItemId != null).length;
    int discardedCount = _mappings.where((m) => m.newItemId == null).length;
    int unmappedNewCount = widget.newItems.where((newItem) {
      return !_mappings.any((m) => m.newItemId == newItem.id);
    }).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("遷移預覽"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 統計摘要
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryCardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("已映射：$mappedCount 個項目"),
                    Text("將捨棄：$discardedCount 個項目"),
                    Text("新項目中未指定來源：$unmappedNewCount 個"),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 新配分明細
              Text("遷移後的新配分：", style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...widget.newItems.map((newItem) {
                final sourceMappings = _getMappingsForNewItem(newItem.id);
                final migratedScore = sourceMappings.isNotEmpty
                    ? _calculateMigratedScore(sourceMappings.first)
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text("- ${newItem.name}")),
                      if (sourceMappings.isNotEmpty)
                        Text(
                          "${migratedScore?.toStringAsFixed(1) ?? '未輸入'} 分",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: migratedScore != null
                                ? Colors.green
                                : colorScheme.subtitleText,
                          ),
                        )
                      else
                        Text(
                          "未輸入",
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("返回修改"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmMigration();
            },
            child: const Text("確認遷移"),
          ),
        ],
      ),
    );
  }

  void _confirmMigration() {
    // 建立遷移結果
    final result = _mappings.where((m) => m.newItemId != null).map((m) {
      return {
        'oldItemId': m.oldItemId,
        'newItemId': m.newItemId,
        'score': _calculateMigratedScore(m),
      };
    }).toList();

    Navigator.pop(context, result);
  }
}

/// 顯示分數遷移助手
///
/// 回傳 List<Map<String, dynamic>>?，每個項目包含:
/// - oldItemId: 舊項目 ID
/// - newItemId: 新項目 ID
/// - score: 遷移後的分數
///
/// 回傳 null 表示使用者取消
Future<List<Map<String, dynamic>>?> showScoreMigrationDialog({
  required BuildContext context,
  required List<ScoreItem> oldItems,
  required List<ScoreItem> newItems,
  required String courseName,
}) async {
  return showDialog(
    context: context,
    builder: (context) => ScoreMigrationDialog(
      oldItems: oldItems,
      newItems: newItems,
      courseName: courseName,
    ),
  );
}