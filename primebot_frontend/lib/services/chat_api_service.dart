import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primebot_frontend/models/chat_response.dart';
import 'package:primebot_frontend/models/chat_session.dart';
import 'package:primebot_frontend/services/api_config.dart';

class ChatApiException implements Exception {
  final String message;
  const ChatApiException(this.message);

  @override
  String toString() => message;
}

class ChatApiService {
  ChatApiService._();
  static final ChatApiService instance = ChatApiService._();

  Future<ChatResponse> sendMessage(String message, {List<ChatMessage> history = const []}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'history': history
                  .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw ChatApiException('Server error (${response.statusCode})');
      }

      return ChatResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on ChatApiException {
      rethrow;
    } catch (e) {
      throw ChatApiException('Could not reach PrimeBot server: $e');
    }
  }
}
