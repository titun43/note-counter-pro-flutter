# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Kotlin metadata
-keep class kotlin.Metadata { *; }

# Play Core (don't warn, we don't use deferred components)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**

# Printing plugin
-keep class net.nprints.** { *; }
-dontwarn net.nprints.**

# PDF
-keep class io.flutter.plugins.** { *; }
