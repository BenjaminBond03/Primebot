import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:primebot_frontend/models/chat_response.dart';
import 'package:primebot_frontend/models/chat_session.dart';
import 'package:primebot_frontend/services/chat_api_service.dart';
import 'package:primebot_frontend/services/local_database.dart';
import 'package:primebot_frontend/Screens/account_screen.dart';

const _greyText = Color(0xFF757575);

Map<String, Object?> _sessionRow(ChatSession s) => {
      'id': s.id,
      'title': s.title,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

List<Map<String, Object?>> _messageRows(ChatSession s) {
  return List.generate(s.messages.length, (i) {
    final m = s.messages[i];
    return {
      'session_id': s.id,
      'text': m.text,
      'is_user': m.isUser ? 1 : 0,
      'sources': m.sources == null
          ? null
          : jsonEncode(m.sources!.map((src) => {'url': src.url, 'title': src.title}).toList()),
      'sequence': i,
    };
  });
}

ChatMessage _messageFromRow(Map<String, Object?> row) {
  final sourcesJson = row['sources'] as String?;
  List<ChatSource>? sources;
  if (sourcesJson != null) {
    final decoded = jsonDecode(sourcesJson) as List<dynamic>;
    sources = decoded
        .map((e) => ChatSource(url: e['url'] as String, title: e['title'] as String))
        .toList();
  }
  return ChatMessage(
    text: row['text'] as String,
    isUser: (row['is_user'] as int) == 1,
    sources: sources,
  );
}

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  final List<ChatSession> _sessions = [];
  String? _activeSessionId;

  // Keeps the request payload/prompt size predictable - the backend also
  // caps this independently, so this is purely a client-side bound.
  static const _maxHistoryTurns = 10;

  final List<String> _suggestions = [
    'What are the admission requirements?',
    'How do I register for courses?',
    'When is the next exam period?',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessionRows = await LocalDatabase.instance.getChatSessionRows();
    final loaded = <ChatSession>[];
    for (final row in sessionRows) {
      final id = row['id'] as String;
      final messageRows = await LocalDatabase.instance.getChatMessageRows(id);
      loaded.add(
        ChatSession(
          id: id,
          title: row['title'] as String,
          messages: messageRows.map(_messageFromRow).toList(),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _sessions.addAll(loaded));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final history = _messages.length > _maxHistoryTurns
        ? _messages.sublist(_messages.length - _maxHistoryTurns)
        : List.of(_messages);

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await ChatApiService.instance.sendMessage(text, history: history);
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: response.answer,
            isUser: false,
            sources: response.sources,
          ),
        );
        _persistCurrentSession();
      });
    } on ChatApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text:
                "Sorry, I couldn't reach the PrimeBot server. ${e.message}",
            isUser: false,
          ),
        );
        _persistCurrentSession();
      });
    }
    _scrollToBottom();
  }

  String _deriveTitle(String text) {
    final singleLine = text.replaceAll('\n', ' ').trim();
    return singleLine.length > 40
        ? '${singleLine.substring(0, 40)}...'
        : singleLine;
  }

  void _persistCurrentSession() {
    if (_messages.isEmpty) return;

    _activeSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final session = ChatSession(
      id: _activeSessionId!,
      title: _deriveTitle(_messages.first.text),
      messages: List.of(_messages),
    );

    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.insert(0, session);

    LocalDatabase.instance.upsertChatSessionRow(_sessionRow(session));
    LocalDatabase.instance.replaceChatMessages(session.id, _messageRows(session));
  }

  void _newChat() {
    setState(() {
      _persistCurrentSession();
      _messages.clear();
      _activeSessionId = null;
    });
  }

  void _openSession(ChatSession session) {
    setState(() {
      _persistCurrentSession();
      _activeSessionId = session.id;
      _messages
        ..clear()
        ..addAll(session.messages);
    });
    Navigator.pop(context);
  }

  void _deleteSession(ChatSession session) {
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      if (_activeSessionId == session.id) {
        _activeSessionId = null;
        _messages.clear();
      }
    });
    LocalDatabase.instance.deleteChatSessionRow(session.id);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() {
    _newChat();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: Color(0xFF1A1A2E),
            size: 24,
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Container(
          //   width: 28,
          //   height: 28,
          //   decoration: BoxDecoration(
          //     color: const Color(0xFF1565C0),
          //     borderRadius: BorderRadius.circular(7),
          //   ),
          //   child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
          // ),
          // const SizedBox(width: 8),
          const Text(
            'PrimeBot',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.edit_square,
            color: Color(0xFF1565C0),
            size: 22,
          ),
          onPressed: _newChat,
          tooltip: 'New Chat',
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFEEEEEE)),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            const SizedBox(height: 4),
            _buildNewChatButton(),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            _buildHistorySection(),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            _buildAccountTile(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'PrimeBot',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _startNewChat,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'RECENT',
              style: TextStyle(
                color: _greyText,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: _sessions.isEmpty
                ? _buildHistoryEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) => _buildHistoryTile(_sessions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFFBDBDBD),
            size: 28,
          ),
          const SizedBox(height: 10),
          const Text(
            'Your conversations will show up here',
            textAlign: TextAlign.center,
            style: TextStyle(color: _greyText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(ChatSession session) {
    final isActive = session.id == _activeSessionId;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteSession(session),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(right: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1565C0).withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(
            isActive ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
            color: isActive ? const Color(0xFF1565C0) : _greyText,
            size: 16,
          ),
          title: Text(
            session.title,
            style: TextStyle(
              color: isActive ? const Color(0xFF1565C0) : const Color(0xFF1A1A2E),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _openSession(session),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildAccountTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFF1565C0),
        child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
      ),
      title: const Text(
        'My Account',
        style: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: const Text(
        'Profile & settings',
        style: TextStyle(color: _greyText, fontSize: 11),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _greyText,
        size: 18,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
      },
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How can I help you?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me anything about campus life,\nadmissions, or student services.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          ...List.generate(
            _suggestions.length,
            (i) => _buildSuggestionCard(_suggestions[i]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          _messageController.text = text;
          _sendMessage();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Color(0xFFBDBDBD),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 56),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBotAvatar(radius: 15),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarkdownBody(
                    data: msg.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      a: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      // The LLM is instructed not to emit tables, but if one
                      // slips through, make it scroll horizontally instead of
                      // squeezing columns unreadably into the chat bubble.
                      tableColumnWidth: const IntrinsicColumnWidth(),
                      tableBorder: TableBorder.all(color: const Color(0xFFE0E0E0)),
                      tableHead: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      tableBody: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 13,
                      ),
                      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(
                          Uri.parse(href),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                  if (msg.sources != null && msg.sources!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSourcesRow(msg.sources!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesRow(List<ChatSource> sources) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources
          .map(
            (source) => InkWell(
              onTap: () => launchUrl(
                Uri.parse(source.url),
                mode: LaunchMode.externalApplication,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 13,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        source.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildBotAvatar(radius: 15),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _buildTypingDot(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 7,
      height: 7,
      margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
      decoration: const BoxDecoration(
        color: Color(0xFF1565C0),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBotAvatar({required double radius}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(radius * 0.5),
      ),
      child: Icon(
        Icons.smart_toy_outlined,
        color: Colors.white,
        size: radius * 1.1,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message PrimeBot...',
                        hintStyle: TextStyle(
                          color: Color(0xFFBDBDBD),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
