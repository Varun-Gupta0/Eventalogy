import 'package:cloud_firestore/cloud_firestore.dart';

class SettingModel {
  final String settingId;
  final Map<String, dynamic> value;
  final Timestamp updatedAt;

  const SettingModel({
    required this.settingId,
    required this.value,
    required this.updatedAt,
  });

  factory SettingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SettingModel(
      settingId: data['settingId'] as String? ?? doc.id,
      value: Map<String, dynamic>.from(data['value'] as Map? ?? {}),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'settingId': settingId,
      'value': value,
      'updatedAt': updatedAt,
    };
  }

  SettingModel copyWith({
    String? settingId,
    Map<String, dynamic>? value,
    Timestamp? updatedAt,
  }) {
    return SettingModel(
      settingId: settingId ?? this.settingId,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
