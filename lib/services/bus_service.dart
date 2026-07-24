import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bus_info.dart';
import '../models/bus_time.dart';
import 'bus_parser.dart';
import 'http_client_factory.dart';

class BusService {
  static const String _basePath = 'https://ibus.tbkc.gov.tw/ibus/graphql';

  static BusService? _instance;
  static BusService get instance => _instance ??= BusService._();

  final http.Client _client = createHttpClient();

  BusService._();

  Future<List<BusInfo>> fetchBusInfoList(Locale locale) async {
    final String language = locale.languageCode.contains('zh') ? 'zh' : 'en';
    final String body = jsonEncode(<String, dynamic>{
      'query': kRouteListQuery,
      'variables': <String, dynamic>{'lang': language},
    });

    try {
      final http.Response response = await _client.post(
        Uri.parse(_basePath),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      final String raw = response.bodyBytes.isEmpty
          ? ''
          : utf8.decode(response.bodyBytes, allowMalformed: true);
      if (raw.isEmpty) {
        throw Exception('Empty response');
      }
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final List<BusInfo> list =
          parseIbusRouteList(json, languageCode: language);
      list.sort(_routeListComparator);
      return list;
    } on http.ClientException catch (e) {
      throw Exception('Failed to fetch bus info: ${e.message}');
    }
  }

  Future<List<BusTime>> fetchBusTime(BusInfo busInfo, Locale locale) async {
    final String language = locale.languageCode.contains('zh') ? 'zh' : 'en';
    final String body = jsonEncode(<String, dynamic>{
      'query': kRouteTimesQuery,
      'variables': <String, dynamic>{
        'routeId': busInfo.routeId,
        'lang': language,
      },
    });

    try {
      final http.Response response = await _client.post(
        Uri.parse(_basePath),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );
      final String raw = response.bodyBytes.isEmpty
          ? ''
          : utf8.decode(response.bodyBytes, allowMalformed: true);
      if (raw.isEmpty) {
        throw Exception('Empty response');
      }
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return parseIbusRouteTimes(json, routeId: busInfo.routeId);
    } on http.ClientException catch (e) {
      throw Exception('Failed to fetch bus time: ${e.message}');
    }
  }

  int _routeListComparator(BusInfo a, BusInfo b) {
    final bool aNsysu = nsysuRouteIds.contains(a.routeId);
    final bool bNsysu = nsysuRouteIds.contains(b.routeId);
    if (aNsysu != bNsysu) {
      return aNsysu ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  }
}