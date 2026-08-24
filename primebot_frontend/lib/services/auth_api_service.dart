import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primebot_frontend/models/auth_user.dart';
import 'package:primebot_frontend/services/api_config.dart';

class AuthApiException implements Exception {
  final String message;
  const AuthApiException(this.message);

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService._();
  static final AuthApiService instance = AuthApiService._();

  Future<AuthUser> signup({
    required String username,
    required String email,
    required String password,
  }) {
    return _post('/auth/signup', {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<AuthUser> login({required String email, required String password}) {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  Future<AuthUser> updateProfile({
    required int userId,
    required String username,
    required String email,
  }) {
    return _put('/auth/profile', {
      'user_id': userId,
      'username': username,
      'email': email,
    });
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send('POST', '/auth/change-password', {
      'user_id': userId,
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<AuthUser> _post(String path, Map<String, Object> body) async {
    final json = await _send('POST', path, body);
    return AuthUser.fromJson(json);
  }

  Future<AuthUser> _put(String path, Map<String, Object> body) async {
    final json = await _send('PUT', path, body);
    return AuthUser.fromJson(json);
  }

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, Object> body) async {
    try {
      final uri = Uri.parse('$apiBaseUrl$path');
      final headers = {'Content-Type': 'application/json'};
      final encodedBody = jsonEncode(body);

      final response = await (method == 'PUT'
              ? http.put(uri, headers: headers, body: encodedBody)
              : http.post(uri, headers: headers, body: encodedBody))
          .timeout(const Duration(seconds: 20));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw AuthApiException(json['detail'] as String? ?? 'Something went wrong');
      }

      return json;
    } on AuthApiException {
      rethrow;
    } catch (e) {
      throw AuthApiException('Could not reach PrimeBot server: $e');
    }
  }
}
