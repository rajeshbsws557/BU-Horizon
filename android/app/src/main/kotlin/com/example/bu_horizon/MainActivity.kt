package com.example.bu_horizon

import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native helpers the bus alarm needs.
 *
 * 1. SETTINGS DEEP LINKS
 *    Telling a user to "enable the permission in Settings" is useless when no
 *    such permission entry exists. On Android 12 and below `POST_NOTIFICATIONS`
 *    isn't a runtime permission at all, so App info -> Permissions shows
 *    nothing for it — the switch that controls whether an alarm can be heard
 *    lives under App info -> *Notifications*. These handlers go straight there.
 *
 * 2. RINGTONE RESOLUTION
 *    `content://settings/system/ringtone` is an indirection handled by
 *    RingtoneManager, NOT a playable media URI. Handing it to
 *    `NotificationChannel.setSound()` leaves many devices silent while
 *    vibration still works — exactly the "vibrates but no sound" symptom.
 *    `getActualDefaultRingtoneUri` resolves it to a concrete
 *    `content://media/...` URI that the system can actually play.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "bu_horizon/app_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                    "openAppSettings" -> result.success(openAppDetailsSettings())
                    "resolveAlarmSoundUri" -> result.success(resolveAlarmSoundUri())
                    "hasDrawable" -> result.success(
                        hasDrawable(call.argument<String>("name")),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * A concrete, playable URI for the user's chosen ringtone.
     *
     * Ordered by what the user actually asked for (their ringtone), then by
     * what is most likely to exist. Returns null when nothing resolves, so Dart
     * can fall back to the platform default rather than scheduling silence.
     */
    private fun resolveAlarmSoundUri(): String? {
        val candidates = listOf(
            RingtoneManager.TYPE_RINGTONE,
            RingtoneManager.TYPE_ALARM,
            RingtoneManager.TYPE_NOTIFICATION,
        )

        for (type in candidates) {
            try {
                // "Actual" resolves the indirection to real media; the plain
                // getDefaultUri would just hand back the settings URI again.
                val actual = RingtoneManager.getActualDefaultRingtoneUri(this, type)
                if (actual != null && isPlayable(actual)) return actual.toString()
            } catch (e: Exception) {
                // Some ROMs throw on a type they don't define — try the next.
            }
        }

        // Last resort: the framework constants. Still better than silence.
        return try {
            val fallback = Settings.System.DEFAULT_ALARM_ALERT_URI
                ?: Settings.System.DEFAULT_RINGTONE_URI
            fallback?.toString()
        } catch (e: Exception) {
            null
        }
    }

    /** Confirms the URI can actually be opened, so we never ship a dead sound. */
    private fun isPlayable(uri: Uri): Boolean = try {
        contentResolver.openAssetFileDescriptor(uri, "r")?.use { true } ?: false
    } catch (e: Exception) {
        false
    }

    /**
     * Whether a drawable actually exists in the installed APK.
     *
     * The notification icon is referenced only as a Dart string, so R8's
     * resource shrinker once removed it from the release build — and
     * flutter_local_notifications then refused to schedule ANY alarm because
     * its icon was missing. A cosmetic asset must never be able to do that, so
     * Dart checks first and falls back to the launcher icon if it's gone.
     */
    private fun hasDrawable(name: String?): Boolean {
        if (name.isNullOrBlank()) return false
        return try {
            resources.getIdentifier(name, "drawable", packageName) != 0 ||
                resources.getIdentifier(name, "mipmap", packageName) != 0
        } catch (e: Exception) {
            false
        }
    }

    /** App-level notification settings (where the "allow notifications" switch is). */
    private fun openNotificationSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            if (startSafely(intent)) return true
        }
        // Pre-Oreo (and OEM ROMs that don't honour the intent above) only expose
        // notifications from the generic app details page.
        return openAppDetailsSettings()
    }

    /** Android 12+ "Alarms & reminders" screen; exact alarms are toggled there. */
    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                .setData(Uri.fromParts("package", packageName, null))
            if (startSafely(intent)) return true
        }
        return openAppDetailsSettings()
    }

    private fun openAppDetailsSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))
        return startSafely(intent)
    }

    /**
     * OEM ROMs sometimes ship without the activity these intents target, which
     * would crash the app. Report failure so Dart can fall back to instructions.
     */
    private fun startSafely(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }
}
