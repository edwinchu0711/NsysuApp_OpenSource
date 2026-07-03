# Flutter Core Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.header.min.** { *; }
-keep class io.flutter.LifeCycleObserver { *; }
-keep class io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference { *; }
-dontwarn io.flutter.embedding.**

# Protection for Installed Native Plugins (防止 R8 誤刪原生套件類別)
# 1. Secure Storage (flutter_secure_storage)
-keep class com.it_ne.flutter_secure_storage.** { *; }

# 2. Package Info Plus (package_info_plus)
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# 3. Open Filex (open_filex)
-keep class com.crazecoder.openfile.** { *; }

# 4. Path Provider (path_provider)
-keep class io.flutter.plugins.pathprovider.** { *; }

# 5. Connectivity Plus (connectivity_plus)
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# 6. URL Launcher (url_launcher)
-keep class io.flutter.plugins.urllauncher.** { *; }
