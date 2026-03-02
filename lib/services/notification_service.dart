import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. 初始化
  Future<void> init() async {
    // 設定 Android 本地通知 (當 App 在前台時顯示用)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon'); // 確保 drawable 裡有這個圖示

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    // ⭐ 建立 Notification Channel（關鍵）
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'course_alert_channel',
        '選課通知',
        description: '接收來自系統的選課提醒',
        importance: Importance.max,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
        // 設定 FCM
        await _setupFCM();
      }

  // 2. 設定 Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // A. 請求權限
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('使用者權限狀態: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // B. 訂閱主題 (這是關鍵！GitHub 會發給這個主題)
      await messaging.subscribeToTopic('all_users');
      print("✅ 已訂閱 'all_users' 主題，準備接收 GitHub 推播");

      // C. 處理前景通知 (當 App 打開時，FCM 預設不會跳通知，要手動觸發 Local Notification)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("收到前景訊息: ${message.notification?.title}");
        
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // 如果訊息裡有通知內容，就顯示出來
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'course_alert_channel', // Channel ID
                '選課通知', // Channel Name
                channelDescription: '接收來自系統的選課提醒',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,     // 增加這行可以提高彈出機率
                icon: 'app_icon',
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        }
      });
    }
  }

  // 給 Settings 頁面用的 (如果你想讓使用者手動開關)
  // 其實 FCM 只要訂閱一次就會記住，這裡只是演示如何取消訂閱
  Future<void> toggleNotification(bool enable) async {
    if (enable) {
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      print("🔔 已開啟通知 (訂閱 topic)");
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      print("🔕 已關閉通知 (取消訂閱 topic)");
    }
  }
}