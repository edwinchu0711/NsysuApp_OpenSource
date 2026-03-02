  import 'package:flutter/material.dart';

  class InfoPage extends StatefulWidget {
    const InfoPage({Key? key}) : super(key: key);

    @override
    State<InfoPage> createState() => _InfoPageState();
  }

  class _InfoPageState extends State<InfoPage> {
    // 已移除：Timer 與相關管理員驗證函式

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("使用須知與資訊"),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(
            color: Colors.black87, 
            fontSize: 18, 
            fontWeight: FontWeight.bold
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildInfoItem(1, "初次登入加載", "本 App 初次登入需要較多時間爬取歷年資料，請在進度條介面耐心等候，請勿中途關閉。"),
              _buildInfoItem(2, "增量更新機制", "初始化完成後，每次登入僅會自動更新「近期」的課表與成績資料，以節省流量與時間。"),
              _buildInfoItem(3, "舊資料更新", "若過去資料（超過 1 年）有變動且希望強制同步，請點擊「登出」後重新登入。"),
              _buildInfoItem(4, "開放成績查詢", "此功能僅在每年 5/15~6/15 及 12/15~1/15 自動更新。非此期間若有需要，請進入功能頁面手動更新。"),
              _buildInfoItem(5, "學期資料切換", "系統採用自動化學期識別引擎，每年 2 月起切換至下學期數據，8 月起切換至新學年上學期數據，確保資料時效性。"),
              _buildInfoItem(6, "名次預覽", "此功能顯示之排名並非校方正式官方排名，僅供參考之用。"),
              _buildInfoItem(7, "選課系統", "在學期選課期間可透過 App 進行選課。使用後請務必回到學校官方選課系統再次確認，若因系統同步延遲或錯誤導致選課失敗，恕不負責。"),
              _buildInfoItem(8, "選課助手", "支援使用者自訂預排課程，並提供匯入課表與匯出至選課系統直接選課的功能。"),
              _buildInfoItem(9, "行事曆", "行事曆功能之資料來源未來可能異動，該功能可能無法長期持續運作，請見諒。"),            _buildInfoItem(10, "異常處理功能", "僅在特定時間於「選課系統」內顯示按鈕，供下載並產出異常處理單。"),
              _buildInfoItem(11, "網路大學存取規範", "讀取作業、考試與公告時設有數據保護。請勿頻繁手動重新整理，避免因異常流量遭校方平台封鎖。"),
              _buildInfoItem(12, "畢業審核說明", "受限於資料轉換方式，畢業審核資訊可能不完整，內容僅供參考，請務必以學校官網查詢結果為準。"),
              _buildInfoItem(13, "異常處理與重啟", "若遇到資料無法顯示，請嘗試「完全關閉 App 後重開」，通常可解決暫時性的網路問題。"),
              
              const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
              
              // 最後的免責與開源聲明
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  "⚠️ 重要聲明：使用此 App 產生之任何問題與風險均須由使用者自行承擔。本專案採開源形式，開放大眾自由修改、下載或轉售，感謝您的理解。",
                  style: TextStyle(
                    fontSize: 13, 
                    color: Colors.red[500], 
                    fontWeight: FontWeight.w600,
                    height: 1.5
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    Widget _buildWelcomeCard() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 40),
            SizedBox(height: 10),
            Text("歡迎使用學生服務系統", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text("為了確保最佳使用體驗，請詳閱以下說明", 
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    Widget _buildInfoItem(int index, String title, String content) {
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 5, 
              offset: const Offset(0, 2)
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blue[100],
              child: Text(index.toString(), 
                style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(content, 
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }