import 'package:flutter/material.dart';
import '../services/course_query_service.dart';

// 定義操作類型：加選 或 退選
enum TransactionType { add, drop }

// 暫存購物車的項目模型
class PendingTransaction {
  final String id;        // 課程代碼
  final String name;      // 課程名稱
  final TransactionType type;
  final TextEditingController? pointsController; // 只有加選需要輸入點數
  final dynamic originalData; // 原始資料

  PendingTransaction({
    required this.id,
    required this.name,
    required this.type,
    this.pointsController,
    this.originalData,
  });
}

// 搜尋結果用的暫存 (如果需要的話，雖然後來主要用 CourseJsonData)
class PendingAddCourse {
  final CourseJsonData courseData;
  final TextEditingController pointsController;

  PendingAddCourse({required this.courseData})
      : pointsController = TextEditingController();
}