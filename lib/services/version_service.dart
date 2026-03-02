import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io'; // ★ 需要引入 dart:io 來判斷 Platform
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart'; // ★ 新增引入
// var time = 86400000;
var time = 5;
// ★ 新增一個類別來回傳檢查結果，方便 UI 直接使用
class VersionCheckResult {
  final bool hasNewStable;       // 是否有比現在更高版本的穩定版
  final String currentVersion;
  final AppVersion? latestStable; // 最新穩定版物件
  final AppVersion? latestBeta;   // 最新 Beta 版物件 (若存在且版本高於目前版本)
  final List<AppVersion> history;
  final String? iosStoreLink;

  VersionCheckResult({
    required this.hasNewStable,
    required this.currentVersion,
    this.latestStable,
    this.latestBeta,
    required this.history,
    this.iosStoreLink, // ★ 建構子加入
  });
}

class AppVersion {
  final String version;
  final String date;
  final String description;
  final String downloadUrl;
  final bool isBeta; // 新增
  // ★ 新增這兩個欄位
  final bool isIos; 
  final String? link;

  AppVersion({
    required this.version,
    required this.date,
    required this.description,
    required this.downloadUrl,
    this.isBeta = false,
    this.isIos = false, // ★ 預設 false
    this.link,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['版本號'] ?? '',
      date: json['更新日期'] ?? '',
      description: json['更新說明'] ?? '',
      downloadUrl: json['下載連結'] ?? '',
      isBeta: json['Beta']?.toString().toLowerCase() == 'true',
      // ★ 解析 ios 欄位
      isIos: json['ios']?.toString().toLowerCase() == 'true',
      // ★ 解析 link 欄位
      link: json['link'],
    );
  }
}

class VersionService {
  static const String _url = "https://edwinchu0711.github.io/CourseSelectionDateUpdate/version.json";
  static const String _lastFetchKey = 'last_fetch_time';
  static const String _cacheDataKey = 'cached_version_data';

  // ★ 這是你原本的抓取邏輯，保持不變 (但設為 private 或保留 public 都可以，看需求)
  Future<List<AppVersion>> fetchVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastFetch < time) {
      final cachedData = prefs.getString(_cacheDataKey);
      if (cachedData != null) {
        return _parseJson(cachedData);
      }
    }

    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        await prefs.setInt(_lastFetchKey, now);
        await prefs.setString(_cacheDataKey, response.body);
        return _parseJson(response.body);
      } else {
        throw Exception('無法載入資料');
      }
    } catch (e) {
      final cachedData = prefs.getString(_cacheDataKey);
      if (cachedData != null) return _parseJson(cachedData);
      rethrow;
    }
  }

  // ★★★ 新增：主要的對外方法，直接回傳比對結果
  Future<VersionCheckResult> checkVersionStatus() async {
    final values = await Future.wait([fetchVersions(), PackageInfo.fromPlatform()]);
    final List<AppVersion> apiVersions = values[0] as List<AppVersion>;
    final PackageInfo packageInfo = values[1] as PackageInfo;

    final String currentVerStr = packageInfo.version;
    
    final latestStable = apiVersions.firstWhere((v) => !v.isBeta, orElse: () => apiVersions.first);
    final latestBeta = apiVersions.first.isBeta ? apiVersions.first : null;

    // 1. 先計算版本號是否較新
    bool versionIsHigher = _isVersionHigher(latestStable.version, currentVerStr);
    
    // 2. 根據平台判斷 hasNewStable
    bool hasNewStable = false;
    String? iosLink;

    if (Platform.isIOS) {
      // ★ iOS 邏輯：版本較新 且 ios=true 且 有連結
      if (versionIsHigher && latestStable.isIos && latestStable.link != null && latestStable.link!.isNotEmpty) {
        hasNewStable = true;
        iosLink = latestStable.link;
      } else {
        // 如果是 iOS 但資料沒說這版支援 iOS，就當作沒更新
        hasNewStable = false;
      }
    } else {
      // ★ Android 邏輯：照舊，只要版本新就提示
      hasNewStable = versionIsHigher;
    }
    
    // 3. 處理 Beta (可選：如果要讓 iOS 也能跑 Beta TestFlight，也可依樣畫葫蘆，這裡先針對 Stable)
    AppVersion? validBeta;
    if (latestBeta != null && _isVersionHigher(latestBeta.version, currentVerStr)) {
      // 如果是 iOS，必須也要有 link 或是標記為 ios 才允許 beta (視你需求而定，這裡先簡單處理：iOS 暫不擋 Beta 顯示，或者你可以加一樣的邏輯)
      if (!Platform.isIOS || (latestBeta.isIos && latestBeta.link != null)) {
        validBeta = latestBeta;
      }
    }

    return VersionCheckResult(
      hasNewStable: hasNewStable,
      currentVersion: currentVerStr,
      latestStable: latestStable,
      latestBeta: validBeta,
      history: apiVersions,
      iosStoreLink: iosLink, // ★ 傳回連結
    );
  }

  bool _isVersionHigher(String v1, String v2) {
    List<int> parse(String v) => _cleanVer(v).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final nums1 = parse(v1);
    final nums2 = parse(v2);
    int maxLength = nums1.length > nums2.length ? nums1.length : nums2.length;
    for (int i = 0; i < maxLength; i++) {
      int n1 = i < nums1.length ? nums1[i] : 0;
      int n2 = i < nums2.length ? nums2[i] : 0;
      if (n1 > n2) return true;
      if (n1 < n2) return false;
    }
    return false;
  }


  // ★ 輔助函式：清理版本號字串 (私有)
  String _cleanVer(String v) {
    return v.replaceAll(RegExp(r'[vV]'), '').trim();
  }

  List<AppVersion> _parseJson(String jsonString) {
    List<dynamic> body = jsonDecode(jsonString);
    return body.map((item) => AppVersion.fromJson(item)).toList();
  }
}