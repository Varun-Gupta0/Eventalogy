import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/agent_models.dart';
import '../../../../core/config/api_config.dart';

class AgentChatService {
  // Unified backend URL for all local platforms
  final String baseUrl = '${ApiConfig.baseUrl}/api/agent';

  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  Future<AgentChatResponse> sendMessage(String message, {String? conversationId}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final body = <String, dynamic>{
        'message': message,
      };
      if (conversationId != null) {
        body['conversationId'] = conversationId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45)); // Need sufficient timeout for LLM

      if (response.statusCode == 200) {
        return AgentChatResponse.fromJson(jsonDecode(response.body));
      } else {
        return AgentChatResponse(
          success: false,
          error: 'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AgentChatResponse(
        success: false,
        error: 'Network or timeout error: $e',
      );
    }
  }

  Future<AgentChatResponse> submitApproval(String conversationId, bool approved, {String? note}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final body = <String, dynamic>{
        'conversationId': conversationId,
        'approved': approved,
      };
      if (note != null && note.isNotEmpty) {
        body['note'] = note;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return AgentChatResponse.fromJson(jsonDecode(response.body));
      } else {
        return AgentChatResponse(
          success: false,
          error: 'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AgentChatResponse(
        success: false,
        error: 'Network or timeout error: $e',
      );
    }
  }

  Future<AgentChatResponse> getStatus(String conversationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('User is not authenticated.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/status/$conversationId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AgentChatResponse.fromJson(jsonDecode(response.body));
      } else {
        return AgentChatResponse(
          success: false,
          error: 'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return AgentChatResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }
}
