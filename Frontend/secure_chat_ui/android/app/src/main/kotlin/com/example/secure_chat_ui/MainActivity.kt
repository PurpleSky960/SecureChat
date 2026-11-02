
package com.example.secure_chat_ui

import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "securechat/python_crypto"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }

        val bridge = Python.getInstance().getModule("bridge")

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "handle" -> {
                    val operation = call.argument<String>("operation")
                    val payload = call.argument<String>("payload") ?: "{}"

                    if (operation == null) {
                        result.error("INVALID_ARGUMENT", "Missing operation", null)
                    } else {
                        try {
                            result.success(
                                bridge.callAttr("handle", operation, payload).toString()
                            )
                        } catch (e: Exception) {
                            result.error(
                                "PYTHON_ERROR",
                                "Python crypto operation failed",
                                null
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
