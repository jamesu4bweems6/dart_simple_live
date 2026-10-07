package com.slotsun.slive

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var backgroundChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_live/app_window")
            .setMethodCallHandler { call, result ->
                if (call.method == "finishAndRemoveTask") {
                    finishAndRemoveTask()
                    result.success(isFinishing)
                } else {
                    result.notImplemented()
                }
            }
        backgroundChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "simple_live/background_playback",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start", "update" -> {
                        val intent = Intent(
                            this,
                            BackgroundPlaybackService::class.java,
                        ).apply {
                            putExtra(
                                "state",
                                call.argument<String>("state")
                                    ?: BackgroundPlaybackService.STATE_PLAYING,
                            )
                            putExtra("title", call.argument<String>("title") ?: "")
                            putExtra("subtitle", call.argument<String>("subtitle") ?: "")
                        }
                        var launched = true
                        try {
                            if (call.method == "start") {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    startForegroundService(intent)
                                } else {
                                    startService(intent)
                                }
                            } else {
                                startService(intent)
                            }
                        } catch (t: Throwable) {
                            launched = false
                            android.util.Log.w(
                                "BackgroundPlayback",
                                "service launch failed: ${t.message}",
                            )
                        }
                        result.success(launched)
                    }

                    "stop" -> {
                        try {
                            stopService(
                                Intent(this, BackgroundPlaybackService::class.java),
                            )
                        } catch (_: Throwable) {
                        }
                        result.success(null)
                    }

                    "isBatteryOptimizationIgnored" -> {
                        val powerManager =
                            getSystemService(POWER_SERVICE) as PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }

                    "openBatteryOptimizationSettings" -> {
                        result.success(openBatteryOptimizationSettings())
                    }

                    "openAutoStartSettings" -> {
                        result.success(openAutoStartSettings())
                    }

                    "openAppDetailsSettings" -> {
                        result.success(openAppDetailsSettings())
                    }

                    else -> result.notImplemented()
                }
            }
        }
        BackgroundPlaybackService.eventListener = { event, payload ->
            val arguments = HashMap<String, Any?>()
            arguments["event"] = event
            arguments.putAll(payload)
            backgroundChannel?.invokeMethod("playbackEvent", arguments)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        stopService(Intent(this, BackgroundPlaybackService::class.java))
        BackgroundPlaybackService.eventListener = null
        backgroundChannel?.setMethodCallHandler(null)
        backgroundChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            ).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            return true
        } catch (_: Throwable) {
        }
        return openBatteryOptimizationSettings()
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (_: Throwable) {
            openAppDetailsSettings()
        }
    }

    private fun openAppDetailsSettings(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
            true
        } catch (_: Throwable) {
            false
        }
    }

    /// Try to open the OEM-specific auto-start management screen. Falls back
    /// to the system app details page when the component is unavailable.
    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            // Xiaomi MIUI / HyperOS
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
            // Huawei EMUI / HarmonyOS
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            ),
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            ),
            // OPPO ColorOS
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            ),
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity",
            ),
            ComponentName(
                "com.oplus.safecenter",
                "com.oplus.safecenter.startupapp.StartupAppListActivity",
            ),
            // vivo OriginOS / Funtouch OS
            ComponentName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            ),
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            ),
            // Meizu Flyme
            ComponentName(
                "com.meizu.safe",
                "com.meizu.safe.permission.SmartBGActivity",
            ),
        )
        for (component in candidates) {
            try {
                startActivity(
                    Intent().apply {
                        this.component = component
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
                return true
            } catch (_: Throwable) {
            }
        }
        return openAppDetailsSettings()
    }

}
