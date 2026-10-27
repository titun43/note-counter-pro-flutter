// =============================================================================
// Note Counter Pro - Saved UPI ID Model
// =============================================================================
// Stores a user-saved UPI ID for quick payment access.
// Groups: favorites, business, family, other
// =============================================================================

class SavedUpi {
  final String id;
  final String upiId;
  final String name;
  final String? phone;
  final String group; // 'favorites', 'business', 'family', 'other'
  final DateTime createdAt;

  SavedUpi({
    required this.id,
    required this.upiId,
    required this.name,
    this.phone,
    required this.group,
    required this.createdAt,
  });

  factory SavedUpi.create({
    required String upiId,
    required String name,
    String? phone,
    String group = 'other',
  }) {
    return SavedUpi(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      upiId: upiId.trim(),
      name: name.trim(),
      phone: phone?.trim(),
      group: group,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'upiId': upiId,
        'name': name,
        'phone': phone,
        'group': group,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedUpi.fromJson(Map<String, dynamic> json) {
    return SavedUpi(
      id: json['id'] as String,
      upiId: json['upiId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      group: json['group'] as String? ?? 'other',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SavedUpi copyWith({
    String? upiId,
    String? name,
    String? phone,
    String? group,
  }) {
    return SavedUpi(
      id: id,
      upiId: upiId ?? this.upiId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      group: group ?? this.group,
      createdAt: createdAt,
    );
  }
}
