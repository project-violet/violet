package xyz.project.violet

import android.app.Activity
import android.net.VpnService
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "xyz.project.violet/dpitunnel"
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && this is Activity)
                window.isNavigationBarContrastEnforced = false
        } catch (e: NoSuchMethodError) {
        }

        GeneratedPluginRegistrant.registerWith(flutterEngine);

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Note: this method is invoked on the main thread.
            // TODO
            try {
                val i = VpnService.prepare(this)
                if (i != null) {
                    startActivityForResult(i, 1)
                }
//                Tun2HttpVpnService.start(this)
            } catch (e: Exception) {
                result.error(e.message, e.message, null);
            }
        }
    }
}
