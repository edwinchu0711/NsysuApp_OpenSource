import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'storage_service.dart';

class ProgramLinkService {
  static final ProgramLinkService instance = ProgramLinkService._internal();
  ProgramLinkService._internal();

  static const String CACHE_KEY = 'program_links_v1';
  static const String SOURCE_URL = 'https://ctdr.nsysu.edu.tw/class2.php';

  Map<String, String> _linkCache = {}; // normalized name → PDF link
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 1);

  Future<void> loadFromCache() async {
    try {
      final jsonStr = await StorageService.instance.read(CACHE_KEY);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        _linkCache = decoded.map((k, v) => MapEntry(k, v as String));
        _cacheTimestamp = DateTime.now();
      }
    } catch (e) {
      debugPrint('ProgramLinkService: loadFromCache error: $e');
    }
  }

  Future<void> fetchLinks() async {
    try {
      final response = await http.get(Uri.parse(SOURCE_URL));
      if (response.statusCode != 200) return;

      final decoded = response.bodyBytes.isNotEmpty
          ? utf8.decode(response.bodyBytes)
          : response.body;

      final Map<String, String> links = await Isolate.run(() {
        final document = html_parser.parse(decoded);
        final tables = document.querySelectorAll('table.plan');

        if (tables.isEmpty) return <String, String>{};

        final Map<String, String> results = {};
        for (int i = 0; i < tables.length; i++) {
          // Skip the last table (discontinued programs)
          if (i == tables.length - 1) continue;

          final rows = tables[i].querySelectorAll('tr');
          for (final row in rows) {
            // Skip header rows
            if (row.querySelector('th') != null) continue;
            final bgcolor = row.attributes['bgcolor'];
            if (bgcolor != null && bgcolor.toUpperCase() == '#FFFF99') continue;

            final cols = row.querySelectorAll('td');
            if (cols.length < 5) continue;

            final rawName = cols[0].text.trim();
            final cleanName = _extractProgramHint(rawName);

            final linkTag = cols[4].querySelector('a');
            if (linkTag == null) continue;
            final href = linkTag.attributes['href'];
            if (href == null || href.isEmpty) continue;

            final fullUrl = _resolveUrl(href);
            if (cleanName.isNotEmpty) {
              final normalizedName = _normalize(cleanName);
              results[normalizedName] = fullUrl;
            }
          }
        }
        return results;
      });

      _linkCache = links;
      _cacheTimestamp = DateTime.now();
      await _saveToCache();
    } catch (e) {
      debugPrint('ProgramLinkService: fetchLinks error: $e');
    }
  }

  /// Get the PDF link for a program name.
  /// Returns null if no matching link is found.
  /// Automatically fetches if cache is stale or empty.
  Future<String?> getPdfLink(String programName) async {
    if (_linkCache.isEmpty || _isCacheStale()) {
      await loadFromCache();
      if (_linkCache.isEmpty || _isCacheStale()) {
        await fetchLinks();
      }
    }
    final normalizedName = _normalize(programName);
    return _linkCache[normalizedName];
  }

  bool _isCacheStale() {
    if (_cacheTimestamp == null) return true;
    return DateTime.now().difference(_cacheTimestamp!) > _cacheDuration;
  }

  Future<void> _saveToCache() async {
    try {
      final encoded = jsonEncode(_linkCache);
      await StorageService.instance.save(CACHE_KEY, encoded);
    } catch (e) {
      debugPrint('ProgramLinkService: saveToCache error: $e');
    }
  }

  static String _resolveUrl(String href) {
    if (href.startsWith('http')) return href;
    return Uri.parse(SOURCE_URL).resolve(href).toString();
  }

  /// Normalize a program name for comparison by removing all whitespace.
  static String _normalize(String name) {
    return name.replaceAll(RegExp(r'\s+'), '');
  }

  /// Extract the core program name from the raw scraped name,
  /// mirroring the logic in 學程.py's extract_program_hint.
  static String _extractProgramHint(String name) {
    // Step 1: Remove leading year-semester prefix like "112-1-"
    name = name.replaceAll(RegExp(r'^\d{3}-\d-'), '').trim();

    // Step 2: Split at first "學程" followed by space, keep before it
    final parts = RegExp(r'學程\s+').allMatches(name);
    if (parts.isNotEmpty) {
      name = name.substring(0, parts.first.start + 2).trim();
    }

    // Step 3: Remove common administrative suffixes
    final suffixes = [
      RegExp(r'全英語學程.*$'),
      RegExp(r'Program Taught.*$'),
      RegExp(r'自\d+年.*$'),
      RegExp(r'停止受理.*$'),
    ];
    for (final pattern in suffixes) {
      name = name.replaceAll(pattern, '').trim();
    }

    // Step 4: Remove bracket contents (both half and full width)
    name = name.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '');
    name = name.replaceAll(RegExp(r'（.*?）|【.*?】'), '');

    // Step 5: Remove special symbols
    name = name.replaceAll(RegExp(r'[\*\★\#\+\-\s]+'), '');

    return name.trim();
  }
}