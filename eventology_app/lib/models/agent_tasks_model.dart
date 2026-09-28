import 'package:cloud_firestore/cloud_firestore.dart';

class AgentTaskModel {
  final String taskId;
  final String agentType;
  final String eventId;
  final String taskType;
  final Map<String, dynamic> input;
  final Map<String, dynamic>? output;
  final String status;
  final bool requiresApproval;
  final String? approvedBy;
  final Timestamp createdAt;
  final Timestamp? completedAt;

  const AgentTaskModel({
    required this.taskId,
    required this.agentType,
    required this.eventId,
    required this.taskType,
    required this.input,
    this.output,
    required this.status,
    required this.requiresApproval,
    this.approvedBy,
    required this.createdAt,
    this.completedAt,
  });

  factory AgentTaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AgentTaskModel(
      taskId: data['taskId'] as String? ?? doc.id,
      agentType: data['agentType'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      taskType: data['taskType'] as String? ?? '',
      input: Map<String, dynamic>.from(data['input'] as Map? ?? {}),
      output: data['output'] != null ? Map<String, dynamic>.from(data['output'] as Map) : null,
      status: data['status'] as String? ?? '',
      requiresApproval: data['requiresApproval'] as bool? ?? false,
      approvedBy: data['approvedBy'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      completedAt: data['completedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'agentType': agentType,
      'eventId': eventId,
      'taskType': taskType,
      'input': input,
      if (output != null) 'output': output,
      'status': status,
      'requiresApproval': requiresApproval,
      if (approvedBy != null) 'approvedBy': approvedBy,
      'createdAt': createdAt,
      if (completedAt != null) 'completedAt': completedAt,
    };
  }

  AgentTaskModel copyWith({
    String? taskId,
    String? agentType,
    String? eventId,
    String? taskType,
    Map<String, dynamic>? input,
    Map<String, dynamic>? output,
    String? status,
    bool? requiresApproval,
    String? approvedBy,
    Timestamp? createdAt,
    Timestamp? completedAt,
  }) {
    return AgentTaskModel(
      taskId: taskId ?? this.taskId,
      agentType: agentType ?? this.agentType,
      eventId: eventId ?? this.eventId,
      taskType: taskType ?? this.taskType,
      input: input ?? this.input,
      output: output ?? this.output,
      status: status ?? this.status,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
