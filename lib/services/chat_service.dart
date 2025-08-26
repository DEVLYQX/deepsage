// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_service.dart';

class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isComplete; // For streaming messages

  Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isComplete = true,
  });
}

class ChatService {
  final String apiBaseUrl =
      'https://cloud.onyx.app/api'; // Replace with actual API URL
  final AuthService _authService = AuthService();

  WebSocketChannel? _channel;
  StreamController<Message> _messagesController = StreamController.broadcast();
  Stream<Message> get messagesStream => _messagesController.stream;

  String _currentContent = '';
  String _currentMessageId = '';

  // Connect to chat websocket
  Future<void> connectToChat(String threadId) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Close existing connection if any
    await disconnectFromChat();

    // Create a new connection
    // Note: The actual URL format may differ based on the API
    final wsUrl = Uri.parse(
      'wss://cloud.onyx.app/api/chat/stream/$threadId',
    ).replace(queryParameters: {'token': token});

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl.toString()));

    // Listen for incoming messages
    _channel!.stream.listen(
      (dynamic data) {
        // Parse the incoming data
        final Map<String, dynamic> message = jsonDecode(data.toString());

        // Check if this is a new message or a continuation
        if (message.containsKey('messageId') &&
            message['messageId'] != _currentMessageId) {
          // If we had a message in progress, mark it as complete
          if (_currentMessageId.isNotEmpty) {
            _messagesController.add(
              Message(
                id: _currentMessageId,
                content: _currentContent,
                isUser: false,
                timestamp: DateTime.now(),
                isComplete: true,
              ),
            );
          }

          // Start a new message
          _currentMessageId = message['messageId'];
          _currentContent = message['content'] ?? '';

          // Add the initial message
          _messagesController.add(
            Message(
              id: _currentMessageId,
              content: _currentContent,
              isUser: false,
              timestamp: DateTime.now(),
              isComplete: false,
            ),
          );
        } else if (_currentMessageId.isNotEmpty) {
          // This is a continuation of the current message
          _currentContent += message['content'] ?? '';

          // Update the message
          _messagesController.add(
            Message(
              id: _currentMessageId,
              content: _currentContent,
              isUser: false,
              timestamp: DateTime.now(),
              isComplete: message['isComplete'] ?? false,
            ),
          );

          // If the message is complete, reset current message tracking
          if (message['isComplete'] == true) {
            _currentMessageId = '';
            _currentContent = '';
          }
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _messagesController.addError(error);
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
  }

  // Disconnect from chat
  Future<void> disconnectFromChat() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
    }
  }

  // Send a message
  Future<void> sendMessage(String threadId, String content) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      // First add the message to the stream so it appears immediately
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isUser: true,
        timestamp: DateTime.now(),
      );
      _messagesController.add(userMessage);

      // Then send it to the API
      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'threadId': threadId, 'content': content}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      print('Send message error: $e');
      _messagesController.addError(e);
    }
  }

  // Get chat history
  Future<List<Message>> getChatHistory(String threadId) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/chat/history/$threadId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get chat history: ${response.body}');
      }

      final List<dynamic> data = jsonDecode(response.body);

      return data
          .map(
            (item) => Message(
              id: item['id'],
              content: item['content'],
              isUser: item['sender'] == 'user',
              timestamp: DateTime.parse(item['timestamp']),
            ),
          )
          .toList();
    } catch (e) {
      print('Get chat history error: $e');
      throw Exception('Failed to load chat history: $e');
    }
  }

  // Dispose
  void dispose() {
    disconnectFromChat();
    _messagesController.close();
  }
}
