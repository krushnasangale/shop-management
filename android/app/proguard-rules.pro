# Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Keep rules for ML Kit text recognition language models
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# If you only use Latin text recognition, you can ignore the missing classes for other languages
# Otherwise, add the dependencies for the required language models in build.gradle

