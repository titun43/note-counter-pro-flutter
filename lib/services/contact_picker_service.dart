import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactPickerService {
  static const MethodChannel _channel = MethodChannel(
    'com.lokhnathtechnical.notecounterpro/contacts',
  );
  
  /// Requests READ_CONTACTS permission if not already granted.
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;
    
    final result = await Permission.contacts.request();
    return result.isGranted;
  }
  
  /// Picks a contact from the device's contact list.
  /// Automatically requests permission if needed.
  /// Returns a map with 'name' and 'phone' keys, or null if cancelled.
  static Future<Map<String, String>?> pickContact() async {
    // First check/request permission
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Contacts permission denied. Please grant permission in Settings.');
    }
    
    try {
      final result = await _channel.invokeMethod<Map>('pickContact');
      if (result != null) {
        return {
          'name': result['name'] as String? ?? '',
          'phone': result['phone'] as String? ?? '',
        };
      }
      return null;
    } on PlatformException catch (e) {
      throw Exception('Failed to pick contact: ${e.message}');
    }
  }
}
