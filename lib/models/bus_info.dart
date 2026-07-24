import 'dart:convert';

class BusInfo {
  final String? carId;
  final List<String> busIds;
  final String stopName;
  final int routeId;
  final String name;
  final String isOpenData;
  final String departure;
  final String destination;
  final String? updateTime;

  const BusInfo({
    this.carId,
    this.busIds = const <String>[],
    required this.stopName,
    required this.routeId,
    required this.name,
    required this.isOpenData,
    required this.departure,
    required this.destination,
    this.updateTime,
  });

  bool get isOperating => busIds.isNotEmpty;

  factory BusInfo.fromJson(Map<String, dynamic> json) => BusInfo(
        carId: json['CarID'] as String?,
        busIds: (json['BusIDs'] as List<dynamic>?)?.cast<String>() ??
            _busIdsFromCarId(json['CarID'] as String?),
        stopName: json['StopName'] as String,
        routeId: json['RouteID'] as int,
        name: json['Name'] == null
            ? json['NameEn'] as String
            : json['Name'] as String,
        isOpenData: json['isOpenData'] as String,
        departure: json['Departure'] == null
            ? json['DepartureEn'] as String
            : json['Departure'] as String,
        destination: json['Destination'] == null
            ? json['DestinationEn'] as String
            : json['Destination'] as String,
        updateTime: json['UpdateTime'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'CarID': carId,
        'BusIDs': busIds,
        'StopName': stopName,
        'RouteID': routeId,
        'Name': name,
        'isOpenData': isOpenData,
        'Departure': departure,
        'Destination': destination,
        'UpdateTime': updateTime,
      };

  factory BusInfo.fromRawJson(String str) =>
      BusInfo.fromJson(json.decode(str) as Map<String, dynamic>);

  String toRawJson() => jsonEncode(toJson());

  static List<BusInfo>? fromRawList(String rawString) {
    final List<dynamic>? rawList =
        json.decode(rawString) as List<dynamic>?;
    if (rawList == null) return null;
    return List<BusInfo>.from(
      rawList.map((x) => BusInfo.fromJson(x as Map<String, dynamic>)),
    );
  }

  static List<String> _busIdsFromCarId(String? carId) => carId == null
      ? const <String>[]
      : carId
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
}