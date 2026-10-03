import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/config/api_config.dart';

class AdminApiService {
  static const String baseUrl = '${ApiConfig.baseUrl}/api/admin'; // unified for local dev

  static Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  static Future<void> verifyVendor(String vendorId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/vendors/$vendorId/verify'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to verify vendor: ${response.body}');
    }
  }

  static Future<void> changeVendorStatus(String vendorId, String status) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/vendors/$vendorId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to change vendor status: ${response.body}');
    }
  }

  static Future<void> cancelEvent(String eventId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/cancel'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel event: ${response.body}');
    }
  }
}
