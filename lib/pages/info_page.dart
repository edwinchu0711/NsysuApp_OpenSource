import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/layout_style_notifier.dart';
import '../widgets/glass/glass_page_scaffold.dart';
import '../widgets/glass/glass_card.dart';

class InfoItem {
  final String title;
  final String content;
  const InfoItem({required this.title, required this.content});
}

class InfoCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<InfoItem> items;
  const InfoCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class InfoPage extends StatefulWidget {
  const InfoPage({Key? key}) : super(key: key);

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<InfoCategory> categories = const [
    InfoCategory(
      title: "安全與隱私保障",
      icon: Icons.security_rounded,
      color: Colors.green,
      items: [
        InfoItem(
          title: "隱私與資安保障",
          content:
              "本 App 為純本地端運作工具，絕不會將您的校務系統帳號密碼、歷年成績、分數試算與選課資料上傳或儲存至任何第三方伺服器。所有登入憑證與個人資料，皆安全儲存於您個人手機本地安全空間中，請安心使用。",
        ),
      ],
    ),
    InfoCategory(
      title: "帳號與系統同步",
      icon: Icons.sync_rounded,
      color: Colors.blue,
      items: [
        InfoItem(
          title: "初次登入加載",
          content: "本 App 初次登入需要較多時間爬取歷年資料，請在進度條介面耐心等候，請勿中途關閉。",
        ),
        InfoItem(
          title: "增量更新機制",
          content: "初始化完成後，每次登入僅會自動更新「近期」的課表與成績資料，以節省流量與時間。",
        ),
        InfoItem(
          title: "舊資料更新",
          content: "若過去資料（超過 1 年）有變動且希望強制同步，請點擊「登出」後重新登入。",
        ),
        InfoItem(
          title: "離線瀏覽支援",
          content: "App 內建自動快取機制。在無網路連線（離線狀態）時，您仍可正常查詢已同步過的課表、成績與分數試算等資料。",
        ),
        InfoItem(
          title: "異常處理與重啟",
          content: "若遇到資料無法顯示，請嘗試「完全關閉 App 後重開」，通常可解決暫時性的網路問題。",
        ),
      ],
    ),
    InfoCategory(
      title: "課務與成績服務",
      icon: Icons.school_rounded,
      color: Colors.orange,
      items: [
        InfoItem(
          title: "開放成績查詢",
          content: "此功能僅在每年 5/15~6/25 及 12/15~1/25 自動更新。非此期間若有需要，請進入功能頁面手動更新。",
        ),
        InfoItem(
          title: "名次預覽",
          content:
              "此功能顯示之排名並非校方正式官方排名，僅供參考之用。另因抓取之學校平台可能較為不穩定，若發生無法載入之情況屬正常現象。該平台有時可能維護無法使用，或該特定時段學校根本尚未公布名次資訊。",
        ),
        InfoItem(
          title: "選課系統",
          content:
              "在學期選課期間可透過 App 進行選課。使用後請務必回到學校官方選課系統再次確認，若因系統同步延遲或錯誤導致選課失敗，恕不負責。",
        ),
        InfoItem(title: "選課助手", content: "支援使用者自訂預排課程，並提供匯入課表與匯出至選課系統直接選課的功能。"),
        InfoItem(title: "異常處理功能", content: "僅在特定時間於「選課系統」內顯示按鈕，供下載並產出異常處理單。"),
        InfoItem(
          title: "畢業審核說明",
          content: "受限於資料轉換方式，畢業審核資訊可能不完整，內容僅供參考，請務必以學校官網查詢結果為準。",
        ),
      ],
    ),
    InfoCategory(
      title: "其它服務與規範",
      icon: Icons.info_outline_rounded,
      color: Colors.purple,
      items: [
        InfoItem(
          title: "網路大學存取規範",
          content: "讀取作業、考試與公告時設有數據保護。請勿頻繁手動重新整理，避免因異常流量遭校方平台封鎖。",
        ),
        InfoItem(
          title: "學程進度說明",
          content:
              "本功能學程規則由 AI 自動解析，數據可能存在誤差；部分跨院認定較為複雜，系統無法涵蓋所有情況；進度百分比為系統估算值，僅供選課參考，不代表最終審核結果。建議同學與系辦再次確認。",
        ),
        InfoItem(title: "行事曆", content: "行事曆功能之資料來源未來可能異動，該功能可能無法長期持續運作，請見諒。"),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;

    if (isWide) {
      return GlassPageScaffold(
        appBar: AppBar(
          title: const Text("使用須知與資訊"),
          backgroundColor:
              isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.primaryText),
          titleTextStyle: TextStyle(
            color: colorScheme.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            40,
            24,
            40,
            LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Category 0 and 2
                      Expanded(
                        child: Column(
                          children: [
                            _buildCategorySection(categories[0]),
                            const SizedBox(height: 24),
                            _buildCategorySection(categories[2]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Category 1 and 3
                      Expanded(
                        child: Column(
                          children: [
                            _buildCategorySection(categories[1]),
                            const SizedBox(height: 24),
                            _buildCategorySection(categories[3]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    height: 60,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildDisclaimerCard(colorScheme),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile layout
    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text("使用須知與資訊"),
        backgroundColor:
            isLiquidGlass ? Colors.transparent : colorScheme.cardBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primaryText),
        titleTextStyle: TextStyle(
          color: colorScheme.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          LayoutStyleNotifier.instance.isLiquidGlass ? 100 : 20,
        ),
        child: Column(
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            ...categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildCategorySection(category),
              ),
            ),
            const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
            _buildDisclaimerCard(colorScheme),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        "⚠️ 重要聲明：使用此 App 產生之任何問題與風險均須由使用者自行承擔。本專案採開源形式，開放大眾自由修改、下載，感謝您的理解。",
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.isDark ? Colors.red[300] : Colors.red[500],
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    if (isLiquidGlass) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: glassCardDecoration(context, borderRadius: 15),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, color: colorScheme.accentBlue, size: 40),
            const SizedBox(height: 10),
            Text(
              "歡迎使用學生服務系統",
              style: TextStyle(
                color: colorScheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "為了確保最佳使用體驗，請詳閱以下說明",
              style: TextStyle(color: colorScheme.subtitleText, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          SizedBox(height: 10),
          Text(
            "歡迎使用學生服務系統",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "為了確保最佳使用體驗，請詳閱以下說明",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(InfoCategory category) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    final isDark = colorScheme.isDark;
    return Container(
      decoration: isLiquidGlass
          ? BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: category.color.withValues(
                  alpha: isDark ? 0.25 : 0.3,
                ),
                width: 1.5,
              ),
            )
          : BoxDecoration(
              color: colorScheme.cardBackground.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: category.color.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 8),
                Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: category.items
                  .map((item) => _buildInfoItem(item, category.color))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(InfoItem item, Color themeColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiquidGlass = LayoutStyleNotifier.instance.isLiquidGlass;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: isLiquidGlass
          ? glassCardDecoration(context, borderRadius: 12)
          : BoxDecoration(
              color: colorScheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.borderColor.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lens,
              size: 8,
              color: themeColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: colorScheme.subtitleText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
