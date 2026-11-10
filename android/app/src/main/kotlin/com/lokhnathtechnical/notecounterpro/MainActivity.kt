package com.lokhnathtechnical.notecounterpro

import android.annotation.SuppressLint
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CONTACT_CHANNEL = "com.lokhnathtechnical.notecounterpro/contacts"
    private val UPDATE_CHANNEL = "com.lokhnathtechnical.notecounterpro/update"
    private val WIDGET_CHANNEL = "com.lokhnathtechnical.notecounterpro/widget"
    private val PICK_CONTACT_REQUEST = 1001
    private var pendingResult: MethodChannel.Result? = null
    private var appUpdateManager: AppUpdateManager? = null
    private val UPDATE_REQUEST_CODE = 2001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Contact picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContact" -> {
                    pendingResult = result
                    // Use Phone.CONTENT_URI directly so the picker shows contacts
                    // with phone numbers, and we get the number straight from the URI
                    val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    startActivityForResult(intent, PICK_CONTACT_REQUEST)
                }
                else -> result.notImplemented()
            }
        }
        
        // In-app update channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUpdate" -> {
                    checkForUpdate(result)
                }
                "startUpdate" -> {
                    startUpdate()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Widget data sync channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    // Batch update: write all data + trigger widget refresh
                    val prefsName = call.argument<String>("prefsName") ?: "NoteCounterWidgetPrefs"
                    val data = call.argument<Map<String, Any>>("data") ?: emptyMap()
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    for ((key, value) in data) {
                        when (value) {
                            is Int -> editor.putInt(key, value)
                            is Long -> editor.putInt(key, value.toInt())
                            is String -> editor.putString(key, value)
                            is Boolean -> editor.putBoolean(key, value)
                        }
                    }
                    editor.apply()
                    triggerWidgetUpdate()
                    result.success(true)
                }
                "updateWidgetData" -> {
                    // Single key-value update
                    val prefsName = call.argument<String>("prefsName") ?: "NoteCounterWidgetPrefs"
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<Any>("value")
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    when (value) {
                        is Int -> editor.putInt(key, value)
                        is Long -> editor.putInt(key, value.toInt())
                        is String -> editor.putString(key, value)
                        is Boolean -> editor.putBoolean(key, value)
                    }
                    editor.apply()
                    result.success(true)
                }
                "triggerWidgetUpdate" -> {
                    triggerWidgetUpdate()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Send a broadcast to update all CounterWidgetProvider instances.
     */
    private fun triggerWidgetUpdate() {
        try {
            val intent = Intent(this, CounterWidgetProvider::class.java).apply {
                action = "com.lokhnathtechnical.notecounterpro.UPDATE_WIDGET"
            }
            sendBroadcast(intent)
        } catch (e: Exception) {
            // Silent fail — widget update is non-critical
        }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        try {
            if (appUpdateManager == null) {
                appUpdateManager = AppUpdateManagerFactory.create(this)
            }
            
            val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo
            appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
                if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                    result.success(mapOf(
                        "updateAvailable" to true,
                        "versionCode" to appUpdateInfo.availableVersionCode()
                    ))
                } else {
                    result.success(mapOf("updateAvailable" to false))
                }
            }.addOnFailureListener { e ->
                result.error("UPDATE_CHECK_FAILED", e.message, null)
            }
        } catch (e: Exception) {
            result.error("UPDATE_ERROR", e.message, null)
        }
    }

    private fun startUpdate() {
        try {
            if (appUpdateManager == null) {
                appUpdateManager = AppUpdateManagerFactory.create(this)
            }
            
            val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo
            appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
                if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                    appUpdateManager!!.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.FLEXIBLE,
                        this,
                        UPDATE_REQUEST_CODE
                    )
                }
            }
        } catch (e: Exception) {
            // Silent fail
        }
    }

    @SuppressLint("Range")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_CONTACT_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val contactUri = data.data
                var name = ""
                var phone = ""

                try {
                    // Since we used Phone.CONTENT_URI, the cursor directly contains
                    // DISPLAY_NAME and NUMBER columns — no second query needed.
                    val cursor = contentResolver.query(contactUri!!, null, null, null, null)
                    if (cursor != null && cursor.moveToFirst()) {
                        name = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)) ?: ""
                        phone = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""
                        cursor.close()
                    }
                } catch (e: Exception) {
                    pendingResult?.error("ERROR", e.message, null)
                    pendingResult = null
                    return
                }

                val result = HashMap<String, String>()
                result["name"] = name
                result["phone"] = phone
                pendingResult?.success(result)
                pendingResult = null
            } else {
                pendingResult?.success(null)
                pendingResult = null
            }
        }
    }
}
