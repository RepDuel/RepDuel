import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/secure_storage_service.dart';

class ApiClient {
  final String baseUrl;
  final SecureStorageService _secureStorage;

  ApiClient({
    required this.baseUrl,
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage;

  Future<http.Response> get(String endpoint, {bool auth = true}) async {
    final headers = await _buildHeaders(auth);
    final url = Uri.parse('$baseUrl$endpoint');
    return http.get(url, headers: headers);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = await _buildHeaders(auth);
    final url = Uri.parse('$baseUrl$endpoint');
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = await _buildHeaders(auth);
    final url = Uri.parse('$baseUrl$endpoint');
    return http.put(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> delete(String endpoint, {bool auth = true}) async {
    final headers = await _buildHeaders(auth);
    final url = Uri.parse('$baseUrl$endpoint');
    return http.delete(url, headers: headers);
  }

  Future<Map<String, String>> _buildHeaders(bool auth) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _secureStorage.readToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }
}
