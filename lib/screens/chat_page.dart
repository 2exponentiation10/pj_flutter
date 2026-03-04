import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _lastUserMessage = '';

  static const List<String> _quickPrompts = [
    '북한어와 남한어에서 자주 헷갈리는 단어 5개 알려줘',
    '발음 교정할 때 억양을 어떻게 연습하면 좋아?',
    '일상 대화에서 부드럽게 말하는 표현을 알려줘',
    '면접 상황에서 자연스럽게 말하는 문장 예시를 줘',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        role: _ChatRole.bot,
        content: '남북한 언어 차이, 표현, 발음에 대해 질문해보세요.',
      ),
    );
  }

  Future<void> _sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _lastUserMessage = trimmed;
      _messages.add(_ChatMessage(role: _ChatRole.user, content: trimmed));
    });
    _scrollToBottom();

    try {
      final reply = await _apiService.sendChatMessage(trimmed);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.bot,
            content: reply.trim().isEmpty ? '응답이 비어 있습니다.' : reply.trim(),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.bot,
            content: '요청이 실패했습니다. 네트워크 또는 API 상태를 확인해 주세요.\n$e',
            isError: true,
          ),
        );
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

  void _clearConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(
          const _ChatMessage(
            role: _ChatRole.bot,
            content: '남북한 언어 차이, 표현, 발음에 대해 질문해보세요.',
          ),
        );
    });
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

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메시지를 복사했습니다.')),
    );
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
      appBar: AppBar(
        title: const Text('AI와 대화하기'),
        actions: [
          IconButton(
            tooltip: '대화 초기화',
            onPressed: _messages.length <= 1 ? null : _clearConversation,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: GradientPage(
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Column(
              children: [
                if (_messages.length <= 2)
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                      itemCount: _quickPrompts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final prompt = _quickPrompts[index];
                        return ActionChip(
                          label: Text(prompt, overflow: TextOverflow.ellipsis),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _controller.text = prompt;
                                  _sendMessage(prompt);
                                  _controller.clear();
                                },
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message.role == _ChatRole.user;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onLongPress: () => _copyMessage(message.content),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: media.size.width * 0.84,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? colorScheme.primary
                                  : (isDark
                                      ? const Color(0xFF141A24)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: message.isError
                                    ? Colors.red.shade400
                                    : (isUser
                                        ? colorScheme.primary
                                        : (isDark
                                            ? const Color(0xFF2D3D5A)
                                            : const Color(0xFFDCE3F1))),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : (isDark
                                            ? const Color(0xFFEAF0FF)
                                            : const Color(0xFF1E283B)),
                                  ),
                                ),
                                if (message.isError) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _isLoading ||
                                            _lastUserMessage.isEmpty
                                        ? null
                                        : () => _sendMessage(_lastUserMessage),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('같은 질문 다시 시도'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    12 + media.padding.bottom * 0.2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoading,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: '질문을 입력하세요',
                          ),
                          onSubmitted: (value) {
                            _sendMessage(value);
                            _controller.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                final text = _controller.text;
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

enum _ChatRole { user, bot }

class _ChatMessage {
  final _ChatRole role;
  final String content;
  final bool isError;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
  });
}
