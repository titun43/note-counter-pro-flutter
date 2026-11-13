# =============================================================================
# Note Counter Pro — ProGuard/R8 Rules
# =============================================================================
# R8 full mode obfuscation enabled for Google Play DEX optimization compliance.
# Only keep what's strictly necessary — let R8 obfuscate everything else.
# =============================================================================

# ===== Flutter core (keep plugin interfaces, obfuscate the rest) =====
# Flutter embedding — must keep for app to launch
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }

# ===== Google Mobile Ads (AdMob) =====
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.ads.**

# ===== In-App Purchase (Play Billing) =====
-keep class com.android.billingclient.** { *; }

# ===== Firebase =====
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ===== Google Sign-In =====
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**

# ===== Google ML Kit (OCR) =====
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ===== Mobile Scanner (QR) =====
-keep class com.github.juliansteffen.** { *; }
-dontwarn com.github.juliansteffen.**

# ===== Razorpay =====
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# ===== Kotlin metadata =====
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions, EnclosingMethod

# ===== Play Core (in-app update) =====
-dontwarn com.google.android.play.core.**

# ===== Native libraries =====
-keep class com.lokhnathtechnical.** { *; }

# ===== Model classes (used by Dart via MethodChannel) =====
-keep class **.model.** { *; }
-keep class **.Model { *; }

# ===== Serializable / Parcelable =====
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class **.R$* {
    public <fields>;
}

# ===== Suppress warnings =====
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
