import 'package:primebot_frontend/models/chat_response.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<ChatSource>? sources;

  const ChatMessage({required this.text, required this.isUser, this.sources});
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
  });
}
