# BU Horizon — R8/ProGuard keep rules
#
# WHY THIS FILE EXISTS (the "Missing type parameter." alarm bug)
#
# flutter_local_notifications persists every scheduled alarm as Gson JSON in
# SharedPreferences, and reads it back with anonymous TypeToken subclasses:
#
#   new TypeToken<ArrayList<NotificationDetails>>() {}.getType()   // scheduling
#   new TypeToken<NotificationDetails>() {}.getType()              // at ring time
#
# Gson recovers the `<...>` part from the class's generic *signature*, which R8
# strips by default in release builds. When it's gone, TypeToken throws
#   java.lang.RuntimeException: Missing type parameter.
#
# That single missing attribute produced all three reported symptoms:
#   1. the FIRST alarm saved fine (nothing stored yet -> no read -> no TypeToken)
#   2. EVERY later attempt failed with "Missing type parameter."
#      (appending to the stored list requires reading it back first)
#   3. the app CRASHED when the alarm was due — ScheduledNotificationReceiver
#      deserializes on the broadcast thread, and an uncaught exception there
#      kills the process.
#
# Debug builds don't run R8, which is exactly why this only ever showed up on a
# real installed (release) build.

# --- Gson -------------------------------------------------------------------
# Signature is the critical one; the rest keep annotations/inner-class links
# that Gson's reflection depends on.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# TypeToken and its anonymous subclasses must survive with generics intact.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Fields addressed reflectively by name must not be renamed.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-dontwarn sun.misc.**

# --- flutter_local_notifications -------------------------------------------
# The plugin's model classes are (de)serialised by Gson purely by field name,
# and ScheduledNotificationReceiver / the boot receiver are instantiated by the
# system, so neither may be renamed or stripped.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- Android entry points ---------------------------------------------------
# Receivers referenced only from AndroidManifest.xml.
-keep class * extends android.content.BroadcastReceiver { *; }
