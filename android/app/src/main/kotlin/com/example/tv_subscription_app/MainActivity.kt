package com.example.tv_subscription_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cashfree_upi_handler"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isUpiAvailable" -> {
                    result.success(isUpiAvailable())
                }
                "getInstalledUpiApps" -> {
                    result.success(getInstalledUpiApps())
                }
                "handleUpiIntent" -> {
                    val upiUrl = call.argument<String>("upiUrl")
                    val preferredApp = call.argument<String>("preferredApp")
                    if (upiUrl != null) {
                        pendingResult = result
                        handleUpiIntent(upiUrl, preferredApp)
                    } else {
                        result.error("INVALID_ARGUMENT", "UPI URL is required", null)
                    }
                }
                "isUpiAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(isUpiAppInstalled(packageName))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "getUpiAppDetails" -> {
                    result.success(getUpiAppDetails())
                }
                "parseUpiResponse" -> {
                    val response = call.argument<String>("response")
                    if (response != null) {
                        result.success(parseUpiResponse(response))
                    } else {
                        result.error("INVALID_ARGUMENT", "Response is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isUpiAvailable(): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
        val packageManager = packageManager
        return intent.resolveActivity(packageManager) != null
    }

    private fun getInstalledUpiApps(): List<String> {
        val upiApps = mutableListOf<String>()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
        val packageManager = packageManager
        val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        
        for (resolveInfo in resolveInfos) {
            upiApps.add(resolveInfo.activityInfo.packageName)
        }
        
        return upiApps
    }

    private fun handleUpiIntent(upiUrl: String, preferredApp: String?) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(upiUrl))
            
            if (preferredApp != null) {
                intent.setPackage(preferredApp)
            }
            
            if (intent.resolveActivity(packageManager) != null) {
                startActivityForResult(intent, UPI_REQUEST_CODE)
            } else {
                pendingResult?.error("UPI_NOT_AVAILABLE", "No UPI app available", null)
                pendingResult = null
            }
        } catch (e: Exception) {
            pendingResult?.error("UPI_ERROR", "Error launching UPI intent: ${e.message}", null)
            pendingResult = null
        }
    }

    private fun isUpiAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun getUpiAppDetails(): Map<String, String> {
        val appDetails = mutableMapOf<String, String>()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
        val packageManager = packageManager
        val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        
        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo.packageName
            val appName = resolveInfo.loadLabel(packageManager).toString()
            appDetails[packageName] = appName
        }
        
        return appDetails
    }

    private fun parseUpiResponse(response: String): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        
        try {
            val params = response.split("&")
            for (param in params) {
                val keyValue = param.split("=")
                if (keyValue.size == 2) {
                    result[keyValue[0]] = keyValue[1]
                }
            }
            
            // Determine success based on response code
            val responseCode = result["responseCode"] as? String
            result["success"] = responseCode == "00" || responseCode == "0"
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = "Failed to parse UPI response: ${e.message}"
        }
        
        return result
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == UPI_REQUEST_CODE) {
            val result = mutableMapOf<String, Any>()
            
            if (data != null) {
                val response = data.getStringExtra("response")
                if (response != null) {
                    result.putAll(parseUpiResponse(response))
                } else {
                    result["success"] = resultCode == RESULT_OK
                    result["resultCode"] = resultCode
                }
            } else {
                result["success"] = false
                result["error"] = "No response data received"
            }
            
            pendingResult?.success(result)
            pendingResult = null
        }
    }

    companion object {
        private const val UPI_REQUEST_CODE = 1001
    }
}
