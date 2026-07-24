// 檔案名稱：widgets/course_dropdowns.dart
import 'package:flutter/material.dart';
import '../course_exception_models.dart';
import '../../../widgets/glass/glass_dropdown.dart';

/// 加退選下拉選單元件
class ActionDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const ActionDropdown({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassSingleSelectDropdown(
      label: '加/退選',
      items: const ["", "加選", "退選"],
      value: value ?? "",
      displayMap: const {
        "": "請選擇加/退選",
        "加選": "加選",
        "退選": "退選",
      },
      onChanged: (val) {
        if (val == "") {
          onChanged(null);
        } else {
          onChanged(val);
        }
      },
    );
  }
}

/// 申請原因下拉選單元件
class ReasonDropdown extends StatelessWidget {
  final String? value;
  final List<ReasonOption> reasons;
  final ValueChanged<String?> onChanged;

  const ReasonDropdown({
    Key? key,
    required this.value,
    required this.reasons,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 取得所有原因的 value 清單
    List<String> items = reasons.map((r) => r.value).toList();

    // 如果 value 為 null 且 items 不包含 ""，或是 items 本來就不含空字串，將它加入作為預設「請選擇」
    if (!items.contains("")) {
      items = ["", ...items];
    }

    // 建立 displayMap
    Map<String, String> displayMap = {
      "": "請選擇原因",
    };
    for (var reason in reasons) {
      String cleanText = reason.text
          .replaceAll(RegExp(r'\【.*?\】'), '')
          .trim();
      displayMap[reason.value] = cleanText;
    }

    return GlassSingleSelectDropdown(
      label: '選擇原因',
      items: items,
      value: value ?? "",
      displayMap: displayMap,
      onChanged: (val) {
        if (val == "") {
          onChanged(null);
        } else {
          onChanged(val);
        }
      },
    );
  }
}
