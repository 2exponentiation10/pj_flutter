import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI와 대화하기')),
      body: GradientPage(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.primary
                            : (isDark ? const Color(0xFF141A24) : Colors.white),
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
                      decoration: const InputDecoration(hintText: '질문을 입력하세요'),
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
    );
  }
}
