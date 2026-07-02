// 檔案名稱：course_assistant_models.dart

// ✅ 自訂行程的資料模型
class CustomEvent {
  final String id;
  final String title;
  final String details;
  final String location; // 位置
  final int day;
  final List<String> periods;

  CustomEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.details,
    required this.day,
    required this.periods,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'location': location,
        'day': day,
        'periods': periods,
      };

  factory CustomEvent.fromJson(Map<String, dynamic> json) => CustomEvent(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        details: json['details'] ?? '',
        location: json['location'] ?? '',
        day: json['day'] ?? 1,
        periods: List<String>.from(json['periods'] ?? []),
      );
}

// ✅ 選課助手課表資料模型
class AssistantSchedule {
  final String id;
  final String name;

  AssistantSchedule({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory AssistantSchedule.fromJson(Map<String, dynamic> json) => AssistantSchedule(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
      );
}
