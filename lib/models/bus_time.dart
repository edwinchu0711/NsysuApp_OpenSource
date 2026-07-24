import 'dart:convert';

enum BusDirection { go, back }

enum BusArrivalStatus {
  arriving,
  comingSoon,
  minutes,
  scheduled,
  departed,
  notOperating,
}

class BusTime {
  final int routeId;
  final String stopId;
  final String name;
  final String? arrivedTime;
  final String? realArrivedTime;
  final String isGoBack;
  final int seqNo;
  final BusDirection direction;
  final BusArrivalStatus arrivalStatus;
  final int? etaMinutes;
  final String? scheduledTime;

  const BusTime({
    required this.routeId,
    required this.stopId,
    required this.name,
    this.arrivedTime,
    this.realArrivedTime,
    required this.isGoBack,
    required this.seqNo,
    this.direction = BusDirection.go,
    this.arrivalStatus = BusArrivalStatus.notOperating,
    this.etaMinutes,
    this.scheduledTime,
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
        direction: _busDirectionFromJson(json['Direction']) ??
            (json['isGoBack'] == 'Y' ? BusDirection.back : BusDirection.go),
        arrivalStatus: _busArrivalStatusFromJson(json['ArrivalStatus']) ??
            _legacyArrivalStatus(
              json['ArrivedTime'] as String?,
              json['RealArrivedTime'] as String?,
            ),
        etaMinutes: json['EtaMinutes'] as int?,
        scheduledTime: json['ScheduledTime'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'RouteID': routeId,
        'StopID': stopId,
        'Name': name,
        'ArrivedTime': arrivedTime,
        'RealArrivedTime': realArrivedTime,
        'isGoBack': isGoBack,
        'SeqNo': seqNo,
        'Direction': direction.name,
        'ArrivalStatus': arrivalStatus.name,
        'EtaMinutes': etaMinutes,
        'ScheduledTime': scheduledTime,
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

  static BusDirection? _busDirectionFromJson(dynamic value) {
    if (value is! String) return null;
    for (final d in BusDirection.values) {
      if (d.name == value) return d;
    }
    return null;
  }

  static BusArrivalStatus? _busArrivalStatusFromJson(dynamic value) {
    if (value is! String) return null;
    for (final s in BusArrivalStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }

  static BusArrivalStatus _legacyArrivalStatus(
    String? arrivedTime,
    String? realArrivedTime,
  ) {
    if (arrivedTime == '進站中') return BusArrivalStatus.arriving;
    if (arrivedTime == '將到站') return BusArrivalStatus.comingSoon;
    if (int.tryParse(arrivedTime ?? '') != null) {
      return BusArrivalStatus.minutes;
    }
    if (arrivedTime != null || realArrivedTime != null) {
      return BusArrivalStatus.scheduled;
    }
    return BusArrivalStatus.notOperating;
  }
}