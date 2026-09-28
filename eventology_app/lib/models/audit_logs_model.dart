import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String logId;
  final String actorId;
  final String actorRole;
  final String action;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic>? metadata;
  final Timestamp timestamp;

  const AuditLogModel({
    required this.logId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.metadata,
    required this.timestamp,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AuditLogModel(
      logId: data['logId'] as String? ?? doc.id,
      actorId: data['actorId'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      action: data['action'] as String? ?? '',
      resourceType: data['resourceType'] as String? ?? '',
      resourceId: data['resourceId'] as String? ?? '',
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata'] as Map) : null,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'logId': logId,
      'actorId': actorId,
      'actorRole': actorRole,
      'action': action,
      'resourceType': resourceType,
      'resourceId': resourceId,
      if (metadata != null) 'metadata': metadata,
      'timestamp': timestamp,
    };
  }

  AuditLogModel copyWith({
    String? logId,
    String? actorId,
    String? actorRole,
    String? action,
    String? resourceType,
    String? resourceId,
    Map<String, dynamic>? metadata,
    Timestamp? timestamp,
  }) {
    return AuditLogModel(
      logId: logId ?? this.logId,
      actorId: actorId ?? this.actorId,
      actorRole: actorRole ?? this.actorRole,
      action: action ?? this.action,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
