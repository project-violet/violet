package xyz.project.violet

import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    private val VOLUME_CHANNEL = "xyz.project.violet/volume"
    private val NATIVELIBDIR_CHANNEL = "xyz.project.violet/nativelibdir"

    private var sink: EventChannel.EventSink? = null

    //
    // Source code from https://github.com/tommy351/eh-redux/commit/0f63f6090c91e06c4ef7241847fad173b4afad86
    //
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)
        window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            window.isNavigationBarContrastEnforced = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
                sink = eventSink
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVELIBDIR_CHANNEL).setMethodCallHandler { call, result ->
            // Note: this method is invoked on the main thread.
            if (call.method == "getNativeDir") {
                result.success(applicationContext.applicationInfo.nativeLibraryDir)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            sink?.success(if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) "down" else "up")
            return true
        }

        return super.onKeyDown(keyCode, event)
    }
}
