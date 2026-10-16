# Flutter embedding and plugins (registered reflectively).
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In (Play services auth, used for Google Drive sync).
-keep class com.google.android.gms.** { *; }

# SQLCipher is a native library bundled by the sqlite3 build hook and loaded
# through dart:ffi: it has no Java classes to keep.

# Keep generic signatures and annotations that plugins read reflectively.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Play Core (deferred components) is referenced by the Flutter embedding but
# not used by this app.
-dontwarn com.google.android.play.core.**

# Optional annotation dependencies referenced by some libraries.
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
