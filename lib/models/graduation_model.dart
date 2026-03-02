import 'dart:convert';

class GraduationData {
  final String checkTime; // 審查時間
  final String department; // 系級
  final String studentName; // 姓名
  final String studentId; // 學號
  
  // 學分統計
  final int minCredits; // 最低畢業學分
  final int currentCredits; // 目前累計學分
  
  // 缺修必修 (存課程名稱)
  final List<String> missingRequiredCourses;
  
  // 通識狀態
  final List<GenEdStatus> genEdStatuses;
  
  // 已修選修 (顯示用)
  final List<String> takenElectiveCourses;

  GraduationData({
    required this.checkTime,
    required this.department,
    required this.studentName,
    required this.studentId,
    required this.minCredits,
    required this.currentCredits,
    required this.missingRequiredCourses,
    required this.genEdStatuses,
    required this.takenElectiveCourses,
  });

  // 序列化 (存入快取)
  Map<String, dynamic> toJson() => {
    'checkTime': checkTime,
    'department': department,
    'studentName': studentName,
    'studentId': studentId,
    'minCredits': minCredits,
    'currentCredits': currentCredits,
    'missingRequiredCourses': missingRequiredCourses,
    'genEdStatuses': genEdStatuses.map((e) => e.toJson()).toList(),
    'takenElectiveCourses': takenElectiveCourses,
  };

  // 反序列化 (讀取快取)
  factory GraduationData.fromJson(Map<String, dynamic> json) {
    return GraduationData(
      checkTime: json['checkTime'] ?? '',
      department: json['department'] ?? '',
      studentName: json['studentName'] ?? '',
      studentId: json['studentId'] ?? '',
      minCredits: json['minCredits'] ?? 128,
      currentCredits: json['currentCredits'] ?? 0,
      missingRequiredCourses: List<String>.from(json['missingRequiredCourses'] ?? []),
      genEdStatuses: (json['genEdStatuses'] as List?)
          ?.map((e) => GenEdStatus.fromJson(e))
          .toList() ?? [],
      takenElectiveCourses: List<String>.from(json['takenElectiveCourses'] ?? []),
    );
  }
}

class GenEdStatus {
  final String name; // 項目名稱
  final String status; // 狀態 (符合/未符)
  final String description; // 備註 (缺修學分等)
  final List<String> details; // 子細項 (例如底下的課程列表)

  GenEdStatus({
    required this.name, 
    required this.status, 
    required this.description,
    this.details = const [], // 預設為空
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'description': description,
    'details': details,
  };

  factory GenEdStatus.fromJson(Map<String, dynamic> json) {
    return GenEdStatus(
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      details: List<String>.from(json['details'] ?? []),
    );
  }
}