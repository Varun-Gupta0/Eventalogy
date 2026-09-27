import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../models/ai/models.dart';

abstract class AIPlannerService {
  Future<AIGeneratedPlan> generatePlan(AIEventPlanRequest request);
}

class OpenRouterAIPlannerServiceImpl implements AIPlannerService {
  final String backendUrl = 'http://10.0.2.2:3000/api/ai/generate-event-plan'; // 10.0.2.2 for Android Emulator

  @override
  Future<AIGeneratedPlan> generatePlan(AIEventPlanRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AIGeneratedPlan(
          title: data['title'] ?? 'Your AI Plan',
          summary: data['summary'] ?? '',
          recommendedServices: List<String>.from(data['recommendedServices'] ?? []),
          estimatedTotal: data['estimatedTotal'] ?? 'Unknown',
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback for demo purposes if backend isn't running
      return AIGeneratedPlan(
        title: 'Network Error',
        summary: 'Could not connect to the Eventology AI backend. Please make sure the Node.js server is running on port 3000.',
        recommendedServices: [],
        estimatedTotal: 'N/A',
      );
    }
  }
}
