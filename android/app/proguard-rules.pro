# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.client.** { *; }
-keep class com.google.firebase.** { *; }

# Drift / SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class org.sqlite.database.** { *; }

# Prevent obfuscating generic types in Kotlin/Java which might be used by Flutter plugins
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Don't warn about missing classes that are optional dependencies for some plugins
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
