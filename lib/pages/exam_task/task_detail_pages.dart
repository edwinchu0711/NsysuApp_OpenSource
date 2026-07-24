import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../services/exam_task/elearn_task_HW_service.dart';
import '../../services/offline_error_handler.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout_style_notifier.dart';
import '../../widgets/glass/glass_page_scaffold.dart';
import '../../widgets/glass/glass_dialog.dart';

// --- Helper Functions (保持不變) ---
Widget _buildInfoRow(BuildContext context, String label, String value) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.isDark;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? colorScheme.subtitleText : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? colorScheme.primaryText : Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionTitle(BuildContext context, String title) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.isDark;
  final primaryColor = isDark ? colorScheme.secondary : Colors.indigo;

  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 40,
          height: 3,
          color: primaryColor.withValues(alpha: 0.3),
        ),
      ],
    ),
  );
}

String _fmtDate(String? iso) {
  if (iso == null) return "-";
  try {
    return DateFormat('yyyy.MM.dd HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (e) {
    return iso;
  }
}

Widget _cleanHtml(BuildContext context, String htmlString) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.isDark;

  final themeFontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  final themeFontFamilyFallback = Theme.of(
    context,
  ).textTheme.bodyMedium?.fontFamilyFallback;

  var document = html_parser.parse(htmlString);
  List<InlineSpan> spans = [];

  void _parseNode(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      if (node.text!.trim().isNotEmpty) {
        spans.add(TextSpan(text: node.text));
      }
    } else if (node.nodeType == dom.Node.ELEMENT_NODE) {
      dom.Element element = node as dom.Element;
      if (['p', 'br', 'div'].contains(element.localName)) {
        if (spans.isNotEmpty &&
            spans.last is TextSpan &&
            (spans.last as TextSpan).text != '\n') {
          spans.add(const TextSpan(text: "\n"));
        }
      }
      for (var child in element.nodes) {
        if (['b', 'strong'].contains(element.localName)) {
          if (child.nodeType == dom.Node.TEXT_NODE) {
            spans.add(
              TextSpan(
                text: child.text,
                style: TextStyle(
                  fontFamily: themeFontFamily,
                  fontFamilyFallback: themeFontFamilyFallback,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            _parseNode(child);
          }
        } else {
          _parseNode(child);
        }
      }
      if (['p', 'div'].contains(element.localName)) {
        spans.add(const TextSpan(text: "\n"));
      }
    }
  }

  _parseNode(document.body!);
  return Text.rich(
    TextSpan(
      style: TextStyle(
        fontFamily: themeFontFamily,
        fontFamilyFallback: themeFontFamilyFallback,
        color: isDark ? colorScheme.bodyText : Colors.black87,
        fontSize: 15,
        height: 1.5,
      ),
      children: spans,
    ),
  );
}

// =======================
// 1. 測驗詳情頁
// =======================
class ExamDetailPage extends StatefulWidget {
  final int examId;
  final String title;
  final bool isIgnored;
  final bool isSubmitted; // 新增：是否已完成
  final VoidCallback? onStatusChanged;
  final bool showAppBar;

  const ExamDetailPage({
    Key? key,
    required this.examId,
    required this.title,
    this.isIgnored = false,
    required this.isSubmitted,
    this.onStatusChanged,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String _error = "";
  late bool _currentIgnored;

  @override
  void didUpdateWidget(covariant ExamDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIgnored != oldWidget.isIgnored) {
      setState(() {
        _currentIgnored = widget.isIgnored;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIgnored = widget.isIgnored;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ElearnService.instance.fetchExamDetails(widget.examId);
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _toggleIgnore() {
    showGlassDialog(
      context: context,
      title: Text(_currentIgnored ? "取消忽略" : "忽略此活動"),
      content: Text(
        _currentIgnored
            ? "確定要取消忽略狀態嗎？"
            : "該功能是提供可能團體作業只需要一個人繳交，或只是不想做。\n\n確定要將此活動設為「忽略」嗎？",
      ),
      actions: [
        TextButton(
          child: const Text("取消"),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        TextButton(
          child: const Text("確定"),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await ElearnService.instance.toggleIgnoreTask(
              widget.examId,
              !_currentIgnored,
            );
            setState(() => _currentIgnored = !_currentIgnored);
            widget.onStatusChanged?.call();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return WillPopScope(
      onWillPop: () async {
        if (widget.onStatusChanged != null) {
          return true;
        }
        Navigator.pop(context, _currentIgnored != widget.isIgnored);
        return false;
      },
      child: GlassPageScaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text("測驗詳情"),
                actions: [
                  // 只有「未完成」的任務才能切換忽略狀態
                  if (!widget.isSubmitted)
                    IconButton(
                      icon: Icon(
                        _currentIgnored
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                      onPressed: _toggleIgnore,
                    ),
                ],
              )
            : null,
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: LayoutStyleNotifier.instance.isLiquidGlass
                      ? colorScheme.primary
                      : null,
                ),
              )
            : _error.isNotEmpty
            ? Center(
                child: Text(
                  _error,
                  style: TextStyle(
                    color: isDark ? colorScheme.primaryText : null,
                  ),
                ),
              )
            : _buildContent(context, isDark, colorScheme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final info = _data!['info'];
    final subs = _data!['submissions']['submissions'] as List;
    final endTime = DateTime.parse(info['end_time']);
    final isClosed = DateTime.now().isAfter(endTime);
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentIgnored)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              color: isDark
                  ? Colors.blue.shade900.withValues(alpha: 0.3)
                  : Colors.blue[50],
              child: Text(
                "此活動已被標記為忽略",
                style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? colorScheme.primaryText : Colors.black87,
                  ),
                ),
              ),
              if (!widget.showAppBar && !widget.isSubmitted)
                IconButton(
                  icon: Icon(
                    _currentIgnored ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                  onPressed: _toggleIgnore,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isClosed
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: isClosed ? Colors.red : Colors.green),
            ),
            child: Text(
              isClosed ? "測驗已截止" : "測驗進行中",
              style: TextStyle(
                color: isClosed ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          _buildSectionTitle(context, "基本資訊"),
          Card(
            elevation: 0,
            color: isLiquidGlass
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.45))
                : (isDark
                      ? colorScheme.secondaryCardBackground
                      : Colors.grey[50]),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isLiquidGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.05))
                    : (isDark ? colorScheme.borderColor : Colors.grey[300]!),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    "活動時間",
                    "${_fmtDate(info['start_time'])} - ${_fmtDate(info['end_time'])}",
                  ),
                  _buildInfoRow(
                    context,
                    "公布成績",
                    _fmtDate(info['announce_score_time']),
                  ),
                  _buildInfoRow(
                    context,
                    "公布答案",
                    _fmtDate(info['announce_answer_time']),
                  ),
                  _buildInfoRow(
                    context,
                    "成績比率",
                    "${info['score_percentage']}%",
                  ),
                  _buildInfoRow(context, "次數上限", "${info['submit_times']}"),
                  _buildInfoRow(
                    context,
                    "測驗形式",
                    info['type'] == 'exam' ? '個人測驗' : '團體測驗',
                  ),
                  _buildInfoRow(
                    context,
                    "計分規則",
                    info['score_rule'] == 'highest' ? '最高得分' : '平均得分',
                  ),
                  _buildInfoRow(context, "完成指標", info['completion_criterion']),
                ],
              ),
            ),
          ),

          _buildSectionTitle(context, "繳交紀錄"),
          Card(
            elevation: isLiquidGlass ? 0 : 2,
            color: isLiquidGlass
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.45))
                : null,
            shape: isLiquidGlass
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  )
                : null,
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  isLiquidGlass
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04))
                      : (isDark
                            ? colorScheme.secondaryCardBackground
                            : Colors.grey[200]),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      '最後交卷時間',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? colorScheme.primaryText
                            : Colors.black87,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '成績',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? colorScheme.primaryText
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
                rows: subs.map<DataRow>((s) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _fmtDate(s['submitted_at']),
                          style: TextStyle(
                            color: isDark
                                ? colorScheme.bodyText
                                : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          s['score']?.toString() ?? "-",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? colorScheme.secondary
                                : Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// 2. 作業詳情頁
// =======================
class HomeworkDetailPage extends StatefulWidget {
  final int homeworkId;
  final String title;
  final bool isIgnored;
  final bool isSubmitted; // 新增
  final VoidCallback? onStatusChanged;
  final bool showAppBar;

  const HomeworkDetailPage({
    Key? key,
    required this.homeworkId,
    required this.title,
    this.isIgnored = false,
    required this.isSubmitted,
    this.onStatusChanged,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String _error = "";
  bool _downloading = false;
  late bool _currentIgnored;

  @override
  void didUpdateWidget(covariant HomeworkDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIgnored != oldWidget.isIgnored) {
      setState(() {
        _currentIgnored = widget.isIgnored;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIgnored = widget.isIgnored;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ElearnService.instance.fetchHomeworkDetails(
        widget.homeworkId,
      );
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _toggleIgnore() {
    showGlassDialog(
      context: context,
      title: Text(_currentIgnored ? "取消忽略" : "忽略此活動"),
      content: Text(
        _currentIgnored
            ? "確定要取消忽略狀態嗎？"
            : "該功能是提供可能團體作業只需要一個人繳交，所以你才沒繳交，會是你只是我想做的活動。\n\n確定要將此活動設為「忽略」嗎？",
      ),
      actions: [
        TextButton(
          child: const Text("取消"),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        TextButton(
          child: const Text("確定"),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await ElearnService.instance.toggleIgnoreTask(
              widget.homeworkId,
              !_currentIgnored,
            );
            setState(() => _currentIgnored = !_currentIgnored);
            widget.onStatusChanged?.call();
          },
        ),
      ],
    );
  }

  Future<void> _downloadAndOpen(int refId, String fileName) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });

    if (await OfflineErrorHandler.handleRefresh(context)) {
      setState(() {
        _downloading = false;
      });
      return;
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("正在下載 $fileName ..."), duration: const Duration(seconds: 2)));
      File file = await ElearnService.instance.downloadFile(refId, fileName);
      setState(() {
        _downloading = false;
      });
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception("無法開啟檔案: ${result.message}");
      }
    } catch (e) {
      setState(() {
        _downloading = false;
      });
      if (e is OfflineDisabledException) {
        await OfflineErrorHandler.show(context, e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("錯誤: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.isDark;

    return WillPopScope(
      onWillPop: () async {
        if (widget.onStatusChanged != null) {
          return true;
        }
        Navigator.pop(context, _currentIgnored != widget.isIgnored);
        return false;
      },
      child: GlassPageScaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text("作業詳情"),
                actions: [
                  // 只有「未完成」的任務才能切換忽略狀態
                  if (!widget.isSubmitted)
                    IconButton(
                      icon: Icon(
                        _currentIgnored
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                      onPressed: _toggleIgnore,
                    ),
                ],
              )
            : null,
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: LayoutStyleNotifier.instance.isLiquidGlass
                      ? colorScheme.primary
                      : null,
                ),
              )
            : _error.isNotEmpty
            ? Center(
                child: Text(
                  _error,
                  style: TextStyle(
                    color: isDark ? colorScheme.primaryText : null,
                  ),
                ),
              )
            : _buildContent(context, isDark, colorScheme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final d = _data!['data'];
    final info = _data!;

    final startTime = info['start_time'];
    final endTime = info['end_time'];
    final desc = d['description'] ?? "";
    final uploads = info['uploads'] as List;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentIgnored)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 10),
              color: isDark
                  ? Colors.blue.shade900.withValues(alpha: 0.3)
                  : Colors.blue[50],
              child: Text(
                "此活動已被標記為忽略",
                style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? colorScheme.primaryText : Colors.black87,
                  ),
                ),
              ),
              if (!widget.showAppBar && !widget.isSubmitted)
                IconButton(
                  icon: Icon(
                    _currentIgnored ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _currentIgnored ? "取消忽略" : "忽略活動",
                  onPressed: _toggleIgnore,
                ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, "基本資訊"),
          Card(
            elevation: 0,
            color: isLiquidGlass
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.45))
                : (isDark
                      ? colorScheme.secondaryCardBackground
                      : Colors.grey[50]),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isLiquidGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.05))
                    : (isDark ? colorScheme.borderColor : Colors.grey[300]!),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    "活動時間",
                    "${_fmtDate(startTime)} - ${_fmtDate(endTime)}",
                  ),
                  _buildInfoRow(
                    context,
                    "公布成績",
                    d['announce_score_type'] == 2 ? "馬上公布" : "依設定",
                  ),
                  _buildInfoRow(context, "成績比率", "${d['score_percentage']}%"),
                  _buildInfoRow(
                    context,
                    "作業形式",
                    d['homework_type'] == 'file_upload' ? '個人作業(上傳)' : '一般作業',
                  ),
                  _buildInfoRow(
                    context,
                    "計分規則",
                    d['score_rule'] == 'highest' ? '最高得分' : '平均得分',
                  ),
                  _buildInfoRow(context, "完成指標", info['completion_criterion']),
                  if (info['score'] != null)
                    _buildInfoRow(
                      context,
                      "得分",
                      info['score'].toString().replaceAll(RegExp(r'\.0$'), ''),
                    ),
                ],
              ),
            ),
          ),

          if (desc.isNotEmpty) ...[
            _buildSectionTitle(context, "作業說明"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLiquidGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.45))
                    : (isDark ? colorScheme.cardBackground : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLiquidGlass
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.05))
                      : (isDark ? colorScheme.borderColor : Colors.grey[300]!),
                ),
              ),
              child: _cleanHtml(context, desc),
            ),
          ],

          if (uploads.isNotEmpty) ...[
            _buildSectionTitle(context, "附件下載"),
            ...uploads.map((u) {
              return Card(
                elevation: isLiquidGlass ? 0 : 2,
                margin: const EdgeInsets.only(bottom: 10),
                color: isLiquidGlass
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.45))
                    : null,
                shape: isLiquidGlass
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      )
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.attach_file,
                    color: isDark ? colorScheme.secondary : Colors.indigo,
                  ),
                  title: Text(
                    u['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? colorScheme.primaryText : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    u['type'] ?? "file",
                    style: TextStyle(
                      color: isDark ? colorScheme.subtitleText : Colors.black54,
                    ),
                  ),
                  trailing: Icon(
                    Icons.download_rounded,
                    color: isDark ? colorScheme.iconColor : null,
                  ),
                  onTap: () => _downloadAndOpen(u['reference_id'], u['name']),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
