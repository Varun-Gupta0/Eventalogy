class AgentMessage {
  final String role;
  final String content;
  final String? id;

  AgentMessage({
    required this.role,
    required this.content,
    this.id,
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(
      role: json['role'] as String? ?? 'unknown',
      content: json['content'] as String? ?? '',
      id: json['id'] as String?,
    );
  }
}

class PendingApproval {
  final String approvalId;
  final String summary;
  final double totalEstimatedCost;
  final String status;
  final String? venue;
  final int vendorCount;
  final List<dynamic>? recommendedVendors;
  final Map<String, dynamic>? budgetBreakdown;

  PendingApproval({
    required this.approvalId,
    required this.summary,
    required this.totalEstimatedCost,
    required this.status,
    this.venue,
    required this.vendorCount,
    this.recommendedVendors,
    this.budgetBreakdown,
  });

  factory PendingApproval.fromJson(Map<String, dynamic> json) {
    return PendingApproval(
      approvalId: json['approvalId'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      totalEstimatedCost: (json['totalEstimatedCost'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      venue: json['venue'] as String?,
      vendorCount: json['vendorCount'] as int? ?? 0,
      recommendedVendors: json['recommendedVendors'] as List<dynamic>?,
      budgetBreakdown: json['budgetBreakdown'] as Map<String, dynamic>?,
    );
  }
}

class AgentWorkflowState {
  final String? workflowId;
  final String? conversationId;
  final String? workflowStatus;
  final String? currentStage;
  final String? currentAgent;
  final bool intakeComplete;
  final Map<String, dynamic>? eventRequirements;
  final Map<String, dynamic>? eventPlan;
  final Map<String, dynamic>? budgetBreakdown;
  final String? approvalStatus;
  final List<PendingApproval> pendingApprovals;
  final List<dynamic>? recommendations;
  final String? lastError;
  final List<AgentMessage> messages;

  AgentWorkflowState({
    this.workflowId,
    this.conversationId,
    this.workflowStatus,
    this.currentStage,
    this.currentAgent,
    this.intakeComplete = false,
    this.eventRequirements,
    this.eventPlan,
    this.budgetBreakdown,
    this.approvalStatus,
    this.pendingApprovals = const [],
    this.recommendations,
    this.lastError,
    this.messages = const [],
  });

  factory AgentWorkflowState.fromJson(Map<String, dynamic> json) {
    return AgentWorkflowState(
      workflowId: json['workflowId'] as String?,
      conversationId: json['conversationId'] as String?,
      workflowStatus: json['workflowStatus'] as String?,
      currentStage: json['currentStage'] as String?,
      currentAgent: json['currentAgent'] as String?,
      intakeComplete: json['intakeComplete'] as bool? ?? false,
      eventRequirements: json['eventRequirements'] as Map<String, dynamic>?,
      eventPlan: json['eventPlan'] as Map<String, dynamic>?,
      budgetBreakdown: json['budgetBreakdown'] as Map<String, dynamic>?,
      approvalStatus: json['approvalStatus'] as String?,
      pendingApprovals: (json['pendingApprovals'] as List<dynamic>?)
              ?.map((e) => PendingApproval.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: json['recommendations'] as List<dynamic>?,
      lastError: json['lastError'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => AgentMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AgentChatResponse {
  final bool success;
  final String? conversationId;
  final bool interrupted;
  final AgentWorkflowState? state;
  final String? error;

  AgentChatResponse({
    required this.success,
    this.conversationId,
    this.interrupted = false,
    this.state,
    this.error,
  });

  factory AgentChatResponse.fromJson(Map<String, dynamic> json) {
    return AgentChatResponse(
      success: json['success'] as bool? ?? false,
      conversationId: json['conversationId'] as String?,
      interrupted: json['interrupted'] as bool? ?? false,
      state: json['state'] != null
          ? AgentWorkflowState.fromJson(json['state'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}
