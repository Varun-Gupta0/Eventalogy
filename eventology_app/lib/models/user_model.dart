import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: users/{uid}
///
/// Document ID: Firebase Authentication UID
/// Database: user-data
///
/// NOTE: The `role` field here is informational only.
/// Authorization MUST rely on Firebase Custom Claims, NOT this field.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? photoUrl;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    Timestamp? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role, // Role is immutable from the client side
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static void validate(Map<String, dynamic> data) {
    assert((data['uid'] as String?)?.isNotEmpty == true, 'uid must not be empty');
    assert((data['name'] as String?)?.isNotEmpty == true, 'name must not be empty');
    assert((data['email'] as String?)?.isNotEmpty == true, 'email must not be empty');
    assert(['user', 'vendor', 'admin'].contains(data['role']), 'role must be user/vendor/admin');
  }
}
