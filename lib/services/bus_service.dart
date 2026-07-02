import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/bus_info.dart';
import '../models/bus_time.dart';

class BusService {
  static const String _basePath = 'https://ibus.nsysu.edu.tw';
  static const String _infoBaseUrl =
      'https://nsysu-code-club.github.io/nsysu-bus';

  static BusService? _instance;
  static BusService get instance => _instance ??= BusService._();

  final Dio _dio = Dio();

  BusService._();

  Future<List<BusInfo>> fetchBusInfoList(Locale locale) async {
    final String languageCode =
        locale.languageCode.contains('zh') ? 'zh' : 'en';
    final String url =
        '$_infoBaseUrl/bus_info_data_$languageCode.json';

    try {
      final Response<String> response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.data != null) {
        final List<BusInfo>? list = BusInfo.fromRawList(response.data!);
        return list ?? [];
      }
      throw Exception('Empty response');
    } on DioException catch (e) {
      throw Exception('Failed to fetch bus info: ${e.message}');
    }
  }

  Future<List<BusTime>> fetchBusTime(BusInfo busInfo, Locale locale) async {
    final String languageCode =
        locale.languageCode.contains('zh') ? 'zh' : 'en';

    try {
      final Response<String> response = await _dio.post<String>(
        '$_basePath/API/RoutePathStop.aspx?${DateTime.now().millisecondsSinceEpoch}',
        options: Options(responseType: ResponseType.plain),
        data: FormData.fromMap(<String, dynamic>{
          'RID': busInfo.routeId,
          'C': languageCode,
          'CID': busInfo.carId,
        }),
      );
      if (response.data != null) {
        final List<BusTime>? list = BusTime.fromRawList(response.data!);
        return list ?? [];
      }
      throw Exception('Empty response');
    } on DioException catch (e) {
      throw Exception('Failed to fetch bus time: ${e.message}');
    }
  }
}