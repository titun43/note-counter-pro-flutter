package com.lokhnathtechnical.notecounterpro

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.lokhnathtechnical.notecounterpro/contacts"
    private val PICK_CONTACT_REQUEST = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContact" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                    intent.type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
                    startActivityForResult(intent, PICK_CONTACT_REQUEST)
                }
                else -> result.notImplemented()
            }
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
                    val cursor = contentResolver.query(contactUri!!, null, null, null, null)
                    if (cursor != null && cursor.moveToFirst()) {
                        val hasPhone = cursor.getInt(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.HAS_PHONE_NUMBER))
                        if (hasPhone > 0) {
                            name = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)) ?: ""
                            val contactId = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                            
                            val phones = contentResolver.query(
                                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                null,
                                ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = " + contactId,
                                null,
                                null
                            )
                            if (phones != null && phones.moveToFirst()) {
                                phone = phones.getString(phones.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""
                                phones.close()
                            }
                        }
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
