import 'dart:convert';

class BusTime {
  final int routeId;
  final String stopId;
  final String name;
  final String? arrivedTime;
  final String? realArrivedTime;
  final String isGoBack;
  final int seqNo;

  const BusTime({
    required this.routeId,
    required this.stopId,
    required this.name,
    this.arrivedTime,
    this.realArrivedTime,
    required this.isGoBack,
    required this.seqNo,
  });

  factory BusTime.fromJson(Map<String, dynamic> json) => BusTime(
        routeId: json['RouteID'] as int,
        stopId: json['StopID'] as String,
        name: json['Name'] == null
            ? json['NameEn'] as String
            : json['Name'] as String,
        arrivedTime: json['ArrivedTime'] as String?,
        realArrivedTime: json['RealArrivedTime'] as String?,
        isGoBack: json['isGoBack'] as String,
        seqNo: json['SeqNo'] as int,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'RouteID': routeId,
        'StopID': stopId,
        'Name': name,
        'ArrivedTime': arrivedTime,
        'RealArrivedTime': realArrivedTime,
        'isGoBack': isGoBack,
        'SeqNo': seqNo,
      };

  factory BusTime.fromRawJson(String str) =>
      BusTime.fromJson(json.decode(str) as Map<String, dynamic>);

  String toRawJson() => jsonEncode(toJson());

  static List<BusTime>? fromRawList(String rawString) {
    final List<dynamic>? rawList =
        json.decode(rawString) as List<dynamic>?;
    if (rawList == null) return null;
    return List<BusTime>.from(
      rawList.map((x) => BusTime.fromJson(x as Map<String, dynamic>)),
    );
  }
}