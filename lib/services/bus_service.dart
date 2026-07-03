import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bus_info.dart';
import '../models/bus_time.dart';

class BusService {
  static const String _basePath = 'https://ibus.nsysu.edu.tw';
  static const String _infoBaseUrl =
      'https://nsysu-code-club.github.io/nsysu-bus';

  static BusService? _instance;
  static BusService get instance => _instance ??= BusService._();

  final http.Client _client = http.Client();

  BusService._();

  Future<List<BusInfo>> fetchBusInfoList(Locale locale) async {
    final String languageCode = locale.languageCode.contains('zh')
        ? 'zh'
        : 'en';
    final String url = '$_infoBaseUrl/bus_info_data_$languageCode.json';

    try {
      final http.Response response = await _client.get(Uri.parse(url));
      final String body = response.bodyBytes.isEmpty
          ? ''
          : utf8.decode(response.bodyBytes, allowMalformed: true);
      if (body.isNotEmpty) {
        final List<BusInfo>? list = BusInfo.fromRawList(body);
        return list ?? [];
      }
      throw Exception('Empty response');
    } on http.ClientException catch (e) {
      throw Exception('Failed to fetch bus info: ${e.message}');
    }
  }

  Future<List<BusTime>> fetchBusTime(BusInfo busInfo, Locale locale) async {
    final String languageCode = locale.languageCode.contains('zh')
        ? 'zh'
        : 'en';

    try {
      final http.Response response = await _client.post(
        Uri.parse(
          '$_basePath/API/RoutePathStop.aspx?${DateTime.now().millisecondsSinceEpoch}',
        ),
        body: <String, String>{
          'RID': busInfo.routeId.toString(),
          'C': languageCode,
          'CID': busInfo.carId ?? '',
        },
      );
      final String body = response.bodyBytes.isEmpty
          ? ''
          : utf8.decode(response.bodyBytes, allowMalformed: true);
      if (body.isNotEmpty) {
        final List<BusTime>? list = BusTime.fromRawList(body);
        return list ?? [];
      }
      throw Exception('Empty response');
    } on http.ClientException catch (e) {
      throw Exception('Failed to fetch bus time: ${e.message}');
    }
  }
}
