import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'offline_mode_service.dart';

/// 離線模式下嘗試聯網時拋出的例外。
///
/// UI 層應捕捉此例外並呼叫 `OfflineErrorHandler.show()` 顯示中央對話框。
class OfflineDisabledException implements Exception {
  final String message;
  const OfflineDisabledException([
    this.message = '離線模式下禁止聯網。若要使用此功能,請連接網路並重新開啟 App。',
  ]);

  @override
  String toString() => message;
}

/// 包裝 [http.Client],在離線模式下攔截所有網路呼叫。
///
/// 攔截點在 [send]:所有 `get` / `post` / `head` / `put` / `delete` / `patch`
/// 最終都會走 [send],因此單點攔截即可涵蓋整個 [http.Client] 介面。
class OfflineAwareHttpClient implements http.Client {
  final http.Client _inner;

  OfflineAwareHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.send(request);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.get(url, headers: headers);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.post(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.put(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.delete(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.head(url, headers: headers);
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.patch(url, headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.read(url, headers: headers);
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    if (OfflineModeService.instance.isOffline) {
      return Future.error(const OfflineDisabledException());
    }
    return _inner.readBytes(url, headers: headers);
  }

  @override
  void close() => _inner.close();
}
