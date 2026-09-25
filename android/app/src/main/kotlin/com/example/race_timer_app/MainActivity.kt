package com.owendonnelley.xceleration

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Keeps the screen on while a race runs, so the Timer or Bib Recorder
        // never has to unlock the phone between runners.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xceleration/screen_awake")
            .setMethodCallHandler { call, result ->
                val on = call.arguments as? Boolean
                if (call.method != "setAwake" || on == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (on) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
    }
}
