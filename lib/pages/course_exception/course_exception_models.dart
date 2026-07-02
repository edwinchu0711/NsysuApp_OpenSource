// 檔案名稱：course_exception_models.dart

/// 預設的異常處理課程 (從網頁抓取)
class AbnormalCourse {
  final String id; // checkbox 的 name: CHEM624_22
  final String actionName; // 下拉選單 name: abn_SelClass_CHEM624_22
  final String reasonName; // 原因選單 name: abn_rsn_CHEM624_22
  final String status;
  final String courseNo;
  final String courseName;
  final String credits;
  final String teacher;

  bool isSelected = false;
  String? selectedAction;
  String? selectedReason;

  AbnormalCourse({
    required this.id,
    required this.actionName,
    required this.reasonName,
    required this.status,
    required this.courseNo,
    required this.courseName,
    required this.credits,
    required this.teacher,
  });
}

/// 自行輸入的課程
class ManualCourse {
  String? selectedAction;
  String courseNo = "";
  String? selectedReason;
  bool isExpanded = true; // 是否展開輸入欄位
}

/// 下拉選單的選項
class ReasonOption {
  final String value; // 代碼: A1
  final String text; // 顯示文字

  ReasonOption(this.value, this.text);
}
