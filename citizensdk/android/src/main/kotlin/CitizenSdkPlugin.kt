package org.citizen.sdk

import android.content.Context
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter registration and activity lifecycle for the CitizenSDK vault. */
class CitizenSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        private const val CHANNEL = "citizen/sdk/hardware_secretvault"
    }

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private lateinit var vault: AndroidHardwareSecretVault
    private var activity: FragmentActivity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        vault = AndroidHardwareSecretVault(applicationContext) { activity }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        vault.onMethodCall(call, result)
    }
}
