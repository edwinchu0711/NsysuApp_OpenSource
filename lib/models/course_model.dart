class Course {
  final String name;
  final String code;
  final String professor;
  final String location;
  final String timeString;
  final String credits;
  final String required;
  final String detailUrl;
  final List<CourseTime> parsedTimes;

  Course({
    required this.name,
    required this.code,
    required this.professor,
    required this.location,
    required this.timeString,
    required this.credits,
    required this.required,
    required this.detailUrl,
    required this.parsedTimes,
  });

  // --- 關鍵修改：將 Map 轉換為 Course 物件 ---
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] ?? "",
      code: json['code'] ?? "",
      professor: json['professor'] ?? "",
      location: json['location'] ?? "",
      timeString: json['timeString'] ?? "",
      credits: json['credits'] ?? "",
      required: json['required'] ?? "",
      detailUrl: json['detailUrl'] ?? "",
      parsedTimes: (json['parsedTimes'] as List)
          .map((t) => CourseTime.fromJson(t))
          .toList(),
    );
  }

  // --- 關鍵修改：將 Course 物件轉換為 Map (以便存入快取) ---
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'professor': professor,
      'location': location,
      'timeString': timeString,
      'credits': credits,
      'required': required,
      'detailUrl': detailUrl,
      'parsedTimes': parsedTimes.map((t) => t.toJson()).toList(),
    };
  }
}

class CourseTime {
  final int day;    // 1-7
  final String period; // '1', '2', 'A', 'B'...

  CourseTime(this.day, this.period);

  factory CourseTime.fromJson(Map<String, dynamic> json) {
    return CourseTime(
      json['day'] as int,
      json['period'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'period': period,
    };
  }
}