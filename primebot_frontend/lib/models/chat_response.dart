class ChatSource {
  final String url;
  final String title;

  const ChatSource({required this.url, required this.title});

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      url: json['url'] as String,
      title: json['title'] as String,
    );
  }
}

class ChatResponse {
  final String answer;
  final List<ChatSource> sources;

  const ChatResponse({required this.answer, required this.sources});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] as String,
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((e) => ChatSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
