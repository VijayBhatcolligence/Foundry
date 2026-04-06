# Flutter WebView
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keepclassmembers class io.flutter.plugins.webviewflutter.** { *; }

# mobile_scanner / MLKit barcode
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# Firebase Auth
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.firebase.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter plugin infrastructure
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Gson / JSON reflection
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
