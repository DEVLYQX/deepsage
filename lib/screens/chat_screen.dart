import 'package:deepsage/models/chat_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import '../utils/toast_utils.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;

  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ChatService _chatService = ChatService.instance;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTextEmpty = true;
  bool _aiTyping = false;

  final timeFormatter = DateFormat.Hm();

  late AnimationController _sendButtonAnimationController;
  late Animation<double> _sendButtonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initChat();

    // Initialize animations
    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _sendButtonAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Listen to text changes
    _messageController.addListener(() {
      final isEmpty = _messageController.text.trim().isEmpty;
      if (isEmpty != _isTextEmpty) {
        setState(() => _isTextEmpty = isEmpty);
        if (!isEmpty) {
          _sendButtonAnimationController.forward();
        } else {
          _sendButtonAnimationController.reverse();
        }
      }
    });
  }

  Future<void> _initChat() async {
    try {
      setState(() => _isLoading = true);
      _chatService.chatMessagesStream.listen((msgs) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }, onError: (error) => ToastUtils.showError('Error: $error'));
      // Get chat history
      await _chatService.getChatHistory(widget.threadId);
      setState(() => _isLoading = false);
    } catch (e) {
      ToastUtils.showError('Failed to load chat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _aiTyping) return;

    // Add haptic feedback
    HapticFeedback.lightImpact();
    _isSending = true;
    _aiTyping = true;
    setState(() {});

    _messageController.clear();
    _messageFocusNode.requestFocus();

    try {
      await _chatService.sendMessage(
        text,
        onDone: () {
          _aiTyping = false;
          setState(() => _isSending = false);
        },
        onError: () {
          _aiTyping = false;
          setState(() => _isSending = false);
          ToastUtils.showError('Something went wrong');
        },
      );
    } catch (e) {
      ToastUtils.showError('Failed to send message: $e');
    } finally {
      // setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _sendButtonAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Widget _buildAppBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Row(
        children: [
          Image.asset('assets/splash_logo.png', height: 35),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DeepSage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'AI Assistant',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? const Color(0x99E2E8F0)
                        : const Color(0x99111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: theme.brightness,
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading chat...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? const Color(0xB3E2E8F0) : const Color(0xB3111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x1A6366F1) : const Color(0x1A6366F1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: isDark ? const Color(0xB36366F1) : const Color(0xB36366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? const Color(0xB3E2E8F0) : const Color(0xB3111827),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin chatting',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0x80E2E8F0) : const Color(0x80111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x4DFFFFFF)
                        : const Color(0x4D000000),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message DeepSage...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0x80E2E8F0)
                          : const Color(0x80111827),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_isTextEmpty && !_isSending && !_aiTyping) {
                      _sendMessage();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            AnimatedBuilder(
              animation: _sendButtonScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _sendButtonScaleAnimation.value,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isTextEmpty
                            ? [
                                isDark
                                    ? const Color(0x4DE2E8F0)
                                    : const Color(0x4D111827),
                                isDark
                                    ? const Color(0x33E2E8F0)
                                    : const Color(0x33111827),
                              ]
                            : [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: (_isTextEmpty || _isSending)
                            ? null
                            : _sendMessage,
                        child: Center(
                          child: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFFAFAFA),
            ),
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        }, childCount: _messages.length),
                      ),
                      if (_aiTyping)
                        SliverToBoxAdapter(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              // color: Colors.black,
                              padding: EdgeInsets.only(left: 12),
                              height: 40,
                              alignment: Alignment.centerLeft,
                              child: TypingIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        _buildMessageInput(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(theme),
      ),
      body: GestureDetector(
        onTap: () {
          // Unfocus when tapping outside input field
          FocusScope.of(context).unfocus();
        },
        child: _isLoading ? _buildLoadingState(theme) : _buildChatBody(theme),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = message.messageType == MessageType.user;

    return Container(
      margin: EdgeInsets.only(
        left: isUser ? 64 : 12,
        right: isUser ? 12 : 64,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primary
                : isDark
                ? const Color(0xFF374151)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isUser
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x4D000000)
                    : const Color(0x14000000),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 16,
                    color: isUser ? Colors.white : theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeFormatter.format(message.timeSent.toLocal()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isUser
                            ? const Color(0xB3FFFFFF)
                            : isDark
                            ? const Color(0x99E2E8F0)
                            : const Color(0x99111827),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        // message.isComplete ? Icons.done_all : Icons.access_time,
                        size: 14,
                        color: const Color(0xB3FFFFFF),
                      ),
                    ],
                    // if (!message.isComplete) ...[
                    //   const SizedBox(width: 8),
                    //   SizedBox(
                    //     height: 12,
                    //     width: 12,
                    //     child: CircularProgressIndicator(
                    //       strokeWidth: 1.5,
                    //       valueColor: AlwaysStoppedAnimation<Color>(
                    //         isUser
                    //             ? const Color(0xB3FFFFFF)
                    //             : theme.colorScheme.primary,
                    //       ),
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Typing indicator (Ai generated, rework if need be)
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  // Animation controllers for each of the three dots
  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  // Animations to drive the bouncing effect
  late final Animation<double> _animation1;
  late final Animation<double> _animation2;
  late final Animation<double> _animation3;

  @override
  void initState() {
    super.initState();

    // Initialize all three animation controllers
    // The .repeat(reverse: true) method handles both the looping and the up/down bounce.
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Create a Tween to define the animation range (e.g., from 0 to -10 pixels)
    final Tween<double> tween = Tween<double>(begin: 0.0, end: -10.0);

    // Create the animations and apply a staggered delay using Intervals
    // An Interval creates a sub-section of the overall animation.
    // This makes the dots "take turns" bouncing.
    _animation1 = tween.animate(
      CurvedAnimation(
        parent: _controller1,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
    _animation2 = tween.animate(
      CurvedAnimation(
        parent: _controller2,
        curve: const Interval(
          0.2,
          1.0,
          curve: Curves.easeOut,
        ), // Start after a delay
      ),
    );
    _animation3 = tween.animate(
      CurvedAnimation(
        parent: _controller3,
        curve: const Interval(
          0.4,
          1.0,
          curve: Curves.easeOut,
        ), // Start after a longer delay
      ),
    );
  }

  @override
  void dispose() {
    // Clean up all the controllers when the widget is removed
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  // A helper method to build an individual animated dot
  Widget _buildDot(Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, animation.value),
          child: child,
        );
      },
      child: Container(
        width: 8.0,
        height: 8.0,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildDot(_animation1),
        const SizedBox(width: 4),
        _buildDot(_animation2),
        const SizedBox(width: 4),
        _buildDot(_animation3),
      ],
    );
  }
}
