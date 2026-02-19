import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({'role': 'bot', 'content': '남북한 언어 차이, 표현, 발음에 대해 질문해보세요.'});
  }

  Future<void> _sendMessage(String message) async {
    setState(() {
      _isLoading = true;
      _messages.add({'role': 'user', 'content': message});
    });
    _scrollToBottom();

    try {
      final reply = await _apiService.sendChatMessage(message);
      setState(() {
        _messages.add({'role': 'bot', 'content': reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'bot',
          'content': '채팅 요청 실패: $e',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI와 대화하기')),
      body: GradientPage(
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: media.size.width * 0.84,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? colorScheme.primary
                                : (isDark
                                    ? const Color(0xFF141A24)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUser
                                  ? colorScheme.primary
                                  : (isDark
                                      ? const Color(0xFF2D3D5A)
                                      : const Color(0xFFDCE3F1)),
                            ),
                          ),
                          child: Text(
                            message['content'] ?? '',
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFFEAF0FF)
                                      : const Color(0xFF1E283B)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoading,
                          minLines: 1,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(hintText: '질문을 입력하세요'),
                          onSubmitted: (value) {
                            final text = value.trim();
                            if (text.isEmpty || _isLoading) return;
                            _sendMessage(text);
                            _controller.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                final text = _controller.text.trim();
                                if (text.isEmpty) return;
                                _sendMessage(text);
                                _controller.clear();
                              },
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
