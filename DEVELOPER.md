# NSYSU Mobile App - 開發者指南 (Developer Guide)

本文件專為本專案的開發人員、研究者或二次開發者所寫，旨在說明如何建置開發環境、理解專案架構與配置資料庫。

---

## 🛠️ 開發環境建置 (Development Setup)

### 前置需求
* **Flutter SDK**: `^3.44.6`
* **Dart SDK**: 相容於 Flutter 版本之 Dart SDK

### 安裝與執行步驟
1. **複製專案**：
   ```bash
   git clone <repository-url>
   cd NSYSU_moblie
   ```

2. **安裝相依套件**：
   ```bash
   flutter pub get
   ```

3. **啟動專案**：
   ```bash
   flutter run
   ```

---

## 📂 專案目錄架構與功能模組 (Project Structure & Modules)

本專案依照 Flutter 架構進行模組化分層，主要程式碼均位於 `lib/` 目錄中：

```text
lib/
├── config/       # 本地設定檔（如資料庫連線 db_config.dart）
├── models/       # 資料實體結構（Data Models，定義課程、成績、使用者等 schema）
├── pages/        # 各功能模組 UI 頁面 (Pages & Screens)
│   ├── bus/                 # 校車時刻表與即時動態頁面 (bus_page.dart)
│   ├── course_assistant/    # 選課助手（預排課表、自訂行程與導出/匯入）
│   ├── course_exception/    # 異常處理單 (PDF/DOCX) 自動產生與導出頁面
│   ├── course_selection/    # 即時選課系統、課程查詢與已選狀態 Tab
│   ├── exam_task/           # 網路大學公告、作業與考試任務頁面
│   ├── main_menu/           # 主功能選單與首頁儀表板
│   ├── course_schedule_page.dart         # 主課表顯示與課程詳細大綱
│   ├── course_progress_page.dart         # 課表歷程與學程進度
│   ├── graduation_page.dart              # 畢業學分審核與修習進度
│   ├── open_score_page.dart              # 搶先名次與期末成績預覽
│   ├── score_result_page.dart            # 歷年成績列表與 GPA 計算
│   ├── score_tracking_page.dart          # 成績目標追蹤與數據遷移
│   └── calendar_page.dart                # 校園行事曆頁面
├── services/     # 核心業務邏輯與系統服務層
│   ├── course_history_sync_service.dart   # 歷年修課系所與課程進度對照同步服務
│   ├── bus_service.dart / bus_parser.dart  # 校車動態資料抓取與時刻表解析
│   ├── course_evaluation_service.dart      # 課程大綱與配分比例解析服務
│   ├── course_exception_service.dart       # 異常處理單表格產生服務
│   ├── course_selection_service.dart       # 即時選課系統條件查詢服務
│   ├── course_selection_submit_service.dart# 選課提交與狀態驗證
│   ├── elearn_bulletin_service.dart        # 網路大學公告/作業/考試爬蟲
│   ├── eligibility_checker.dart            # 畢業與學程資格判定邏輯引擎
│   ├── graduation_service.dart             # 畢業學分分類計算服務
│   ├── historical_score_service.dart       # 歷年成績存取與 GPA 運算
│   ├── offline_aware_http_client.dart      # 離線感知 HTTP Client 與快取機制
│   ├── open_score_service.dart             # 搶先名次平台爬蟲與預覽服務
│   ├── program_application_service.dart    # 跨領域/微學程進度服務
│   ├── session_service.dart                # 校方單一入口 Session 狀態管理
│   └── storage_service.dart                # flutter_secure_storage 安全存儲
├── theme/        # App 全域視覺主題與字型設定
├── utils/        # 共用 Helper（如日期、字串、網路連線工具）
└── widgets/      # 跨頁面共用的自訂 UI 元件
```

---

## 🔒 隱私與安全性 (Security & Scraper)

* **憑證保護**：App 內使用 `flutter_secure_storage` 儲存使用者登入憑證，保障敏感資訊安全。
* **增量同步**：在資料抓取（Scraping）時，採用增量同步機制，以降低校方伺服器的頻寬壓力。
