import 'package:cloud_firestore/cloud_firestore.dart';

class AgentLogModel {
  final String logId;
  final String agentType;
  final String taskId;
  final String action;
  final Map<String, dynamic> input;
  final Map<String, dynamic>? output;
  final String result;
  final Timestamp timestamp;

  const AgentLogModel({
    required this.logId,
    required this.agentType,
    required this.taskId,
    required this.action,
    required this.input,
    this.output,
    required this.result,
    required this.timestamp,
  });

  factory AgentLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AgentLogModel(
      logId: data['logId'] as String? ?? doc.id,
      agentType: data['agentType'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      action: data['action'] as String? ?? '',
      input: Map<String, dynamic>.from(data['input'] as Map? ?? {}),
      output: data['output'] != null ? Map<String, dynamic>.from(data['output'] as Map) : null,
      result: data['result'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'logId': logId,
      'agentType': agentType,
      'taskId': taskId,
      'action': action,
      'input': input,
      if (output != null) 'output': output,
      'result': result,
      'timestamp': timestamp,
    };
  }

  AgentLogModel copyWith({
    String? logId,
    String? agentType,
    String? taskId,
    String? action,
    Map<String, dynamic>? input,
    Map<String, dynamic>? output,
    String? result,
    Timestamp? timestamp,
  }) {
    return AgentLogModel(
      logId: logId ?? this.logId,
      agentType: agentType ?? this.agentType,
      taskId: taskId ?? this.taskId,
      action: action ?? this.action,
      input: input ?? this.input,
      output: output ?? this.output,
      result: result ?? this.result,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
