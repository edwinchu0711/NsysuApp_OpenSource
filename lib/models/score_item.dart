import 'dart:math';

/// 配分項目資料模型
/// 支援基本項目與擴展子項目
class ScoreItem {
  final String id;
  final String name;
  final double weight;
  final double? score;
  final List<ScoreItem> children;

  ScoreItem({
    required this.id,
    required this.name,
    required this.weight,
    this.score,
    this.children = const [],
  });

  /// 有效分數：如果有子項目，回傳子項目的加權平均；否則回傳自己的分數
  double? get effectiveScore {
    if (children.isEmpty) return score;

    double totalScore = 0;
    double totalWeight = 0;
    for (var child in children) {
      if (child.effectiveScore != null) {
        totalScore += child.effectiveScore! * child.weight;
        totalWeight += child.weight;
      }
    }
    if (totalWeight <= 0) return null;
    return totalScore / totalWeight;
  }

  /// 是否為父項目（有子項目）
  bool get hasChildren => children.isNotEmpty;

  /// 已輸入的權重
  double get enteredWeight {
    if (children.isEmpty) {
      return score != null ? weight : 0.0;
    }

    double childrenTotalWeight = 0;
    double childrenEnteredWeight = 0;

    for (var child in children) {
      childrenTotalWeight += child.weight;
      childrenEnteredWeight += child.enteredWeight;
    }

    if (childrenTotalWeight <= 0) return 0.0;

    return (childrenEnteredWeight / childrenTotalWeight) * weight;
  }

  /// 計算目前總分
  double? get weightedScore {
    if (children.isEmpty) {
      if (score == null) return null;
      return score! * weight / 100;
    }

    double total = 0;
    bool hasAnyScore = false;
    for (var child in children) {
      final ws = child.weightedScore;
      if (ws != null) {
        total += ws;
        hasAnyScore = true;
      }
    }

    double childrenTotalWeight = children.fold(0.0, (sum, child) => sum + child.weight);
    if (childrenTotalWeight <= 0) return null;

    return hasAnyScore ? (total / childrenTotalWeight) * weight : null;
  }

  ScoreItem copyWith({
    String? id,
    String? name,
    double? weight,
    double? score,
    List<ScoreItem>? children,
    bool clearScore = false,
  }) {
    return ScoreItem(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      score: clearScore ? null : (score ?? this.score),
      children: children ?? this.children,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'score': score,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  factory ScoreItem.fromJson(Map<String, dynamic> json) {
    return ScoreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ScoreItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ScoreItem.fromRawData(String name, double weight) {
    return ScoreItem(
      id: _generateId(),
      name: name,
      weight: weight,
      children: [],
    );
  }

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  static final Random _random = Random();
}

/// 課程配分資料（包含所有項目與目標等第）
class CourseScoreData {
  final String courseId;
  final String courseName;
  final List<ScoreItem> items;
  final String? targetGrade;
  final bool isCustomized;
  final DateTime? lastUpdated;

  CourseScoreData({
    required this.courseId,
    required this.courseName,
    this.items = const [],
    this.targetGrade,
    this.isCustomized = false,
    this.lastUpdated,
  });

  double? get currentTotal {
    double total = 0;
    bool hasAnyScore = false;
    for (var item in items) {
      final ws = item.weightedScore;
      if (ws != null) {
        total += ws;
        hasAnyScore = true;
      }
    }
    return hasAnyScore ? total : null;
  }

  double get enteredWeight {
    double total = 0;
    for (var item in items) {
      total += item.enteredWeight;
    }
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'items': items.map((i) => i.toJson()).toList(),
      'targetGrade': targetGrade,
      'isCustomized': isCustomized,
      'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  factory CourseScoreData.fromJson(Map<String, dynamic> json) {
    return CourseScoreData(
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ScoreItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetGrade: json['targetGrade'] as String?,
      isCustomized: json['isCustomized'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
          : null,
    );
  }

  CourseScoreData copyWith({
    String? courseId,
    String? courseName,
    List<ScoreItem>? items,
    String? targetGrade,
    bool? isCustomized,
    DateTime? lastUpdated,
  }) {
    return CourseScoreData(
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      items: items ?? this.items,
      targetGrade: targetGrade ?? this.targetGrade,
      isCustomized: isCustomized ?? this.isCustomized,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}