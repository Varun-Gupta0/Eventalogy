import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/agent_models.dart';
import '../services/agent_chat_service.dart';
import '../widgets/chat_components.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AgentChatService _chatService = AgentChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _conversationId;
  AgentWorkflowState? _currentState;
  bool _isThinking = false;
  String? _error;
  
  List<AgentMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Add a default greeting
    _messages.add(AgentMessage(
      role: 'assistant', 
      content: 'Hello! I am your Eventology Architect. I can help you plan your dream event, find the best venues, and manage your budget. What would you like to plan today?'
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isThinking) return;
    
    final userText = text.trim();
    _textController.clear();

    setState(() {
      _messages.add(AgentMessage(role: 'user', content: userText));
      _isThinking = true;
      _error = null;
    });

    _scrollToBottom();

    final response = await _chatService.sendMessage(userText, conversationId: _conversationId);

    setState(() {
      _isThinking = false;
      if (response.success && response.state != null) {
        _conversationId = response.conversationId;
        _currentState = response.state;
        
        if (response.state!.messages.isNotEmpty) {
           _messages = response.state!.messages;
        }
      } else {
        _error = response.error ?? 'Something went wrong while connecting to Eventology.';
      }
    });

    _scrollToBottom();
  }

  Future<void> _handleApproval(bool approved, String note) async {
    if (_conversationId == null) return;
    if (_isThinking) return;
    
    setState(() {
      _isThinking = true;
      _error = null;
    });

    final response = await _chatService.submitApproval(_conversationId!, approved, note: note);

    setState(() {
      _isThinking = false;
      if (response.success && response.state != null) {
        _currentState = response.state;
        if (response.state!.messages.isNotEmpty) {
           _messages = response.state!.messages;
        }
      } else {
        _error = response.error ?? 'Failed to submit approval.';
      }
    });
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getFriendlyStageName(String? stage) {
    switch (stage) {
      case 'intake': return 'Understanding your event';
      case 'planning': return 'Building your event plan';
      case 'specialist_search': return 'Finding the best options';
      case 'availability': return 'Checking availability';
      case 'budget': return 'Preparing your budget';
      case 'approval': return 'Waiting for your approval';
      case 'booking': return 'Confirming your booking';
      case 'communication': return 'Sending confirmations';
      case 'completed': return 'Event planned successfully';
      default:
        if (stage != null && stage.isNotEmpty) {
           return 'Working on your event...';
        }
        return 'Ready to plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool needsApproval = _currentState?.workflowStatus == 'suspended' || 
                              (_currentState?.pendingApprovals.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AIChatHeader(
        stageName: _getFriendlyStageName(_currentState?.currentStage),
        onBackPressed: () => context.pop(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900), // Desktop responsiveness limit
          child: Column(
            children: [
              if (_error != null) 
                ErrorMessageCard(
                  error: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: _messages.length + (_isThinking ? 1 : 0) + (needsApproval ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      final msg = _messages[index];
                      if (msg.role == 'user') {
                        return UserMessageBubble(content: msg.content);
                      } else {
                        return AIMessageBubble(content: msg.content);
                      }
                    } else if (_isThinking && index == _messages.length) {
                      return ThinkingIndicator(
                        stageName: _getFriendlyStageName(_currentState?.currentStage)
                      );
                    } else if (needsApproval) {
                       return Container(
                         margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                         child: ElevatedButton(
                           onPressed: () {
                             context.push('/plan-review', extra: {
                               'conversationId': _conversationId,
                               'state': _currentState,
                             });
                           },
                           style: ElevatedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             backgroundColor: AppColors.primary,
                             foregroundColor: Colors.black,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                           ),
                           child: const Text('Review Event Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                         ),
                       );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              AIChatInputBox(
                controller: _textController,
                onSend: _sendMessage,
                isThinking: _isThinking,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
