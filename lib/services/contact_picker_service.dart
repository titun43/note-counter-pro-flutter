import 'package:flutter/services.dart';

class ContactPickerService {
  static const MethodChannel _channel = MethodChannel(
    'com.lokhnathtechnical.notecounterpro/contacts',
  );
  
  /// Picks a contact from the device's contact list.
  /// Returns a map with 'name' and 'phone' keys, or null if cancelled.
  static Future<Map<String, String>?> pickContact() async {
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
