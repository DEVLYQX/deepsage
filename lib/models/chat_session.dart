
class ChatSession {
  ChatSession({
    required this.chatSessionId,
    required this.description,
    required this.personaId,
    required this.personaName,
    required this.messages,
    required this.timeCreated,
  });

  final String? chatSessionId;
  final String? description;
  final int? personaId;
  final String? personaName;
  final List<ChatMessage> messages;
  final DateTime? timeCreated;

  ChatSession copyWith({
    String? chatSessionId,
    String? description,
    int? personaId,
    String? personaName,
    List<ChatMessage>? messages,
    DateTime? timeCreated,
  }) {
    return ChatSession(
      chatSessionId: chatSessionId ?? this.chatSessionId,
      description: description ?? this.description,
      personaId: personaId ?? this.personaId,
      personaName: personaName ?? this.personaName,
      messages: messages ?? this.messages,
      timeCreated: timeCreated ?? this.timeCreated,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json){
    return ChatSession(
      chatSessionId: json["chat_session_id"],
      description: json["description"],
      personaId: json["persona_id"],
      personaName: json["persona_name"],
      messages: json["messages"] == null ? [] : List<ChatMessage>.from(json["messages"]!.map((x) => ChatMessage.fromJson(x))),
      timeCreated: DateTime.tryParse(json["time_created"] ?? ""),
    );
  }

  Map<String, dynamic> toJson() => {
    "chat_session_id": chatSessionId,
    "description": description,
    "persona_id": personaId,
    "persona_name": personaName,
    "messages": messages.map((x) => x).toList(),
    "time_created": timeCreated?.toIso8601String(),
  };

  @override
  String toString(){
    return "$chatSessionId, $description, $personaId, $personaName, $messages, $timeCreated, ";
  }
}


class ChatMessage {
  ChatMessage({
    this.messageId,
    this.parentMessage,
    this.latestChildMessage,
    required this.message,
    required this.messageType,
    required this.timeSent,
    required this.chatSessionId,
    this.citations,
    this.refinedAnswerImprovement,
    this.error,
  });

  final int? messageId;
  final int? parentMessage;
  final int? latestChildMessage;
  final String message;
  final MessageType messageType;
  final DateTime timeSent;
  final String chatSessionId;
  final dynamic citations;
  final dynamic refinedAnswerImprovement;
  final dynamic error;

  ChatMessage copyWith({
    int? messageId,
    int? parentMessage,
    int? latestChildMessage,
    String? message,
    MessageType? messageType,
    DateTime? timeSent,
    String? chatSessionId,
    dynamic? citations,
    List<dynamic>? subQuestions,
    dynamic? refinedAnswerImprovement,
    dynamic? error,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      parentMessage: parentMessage ?? this.parentMessage,
      latestChildMessage: latestChildMessage ?? this.latestChildMessage,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      timeSent: timeSent ?? this.timeSent,
      chatSessionId: chatSessionId ?? this.chatSessionId,
      citations: citations ?? this.citations,
      refinedAnswerImprovement: refinedAnswerImprovement ?? this.refinedAnswerImprovement,
      error: error ?? this.error,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json){
    return ChatMessage(
      messageId: json["message_id"],
      parentMessage: json["parent_message"],
      latestChildMessage: json["latest_child_message"],
      message: json["message"],
      messageType: MessageType.fromJson(json["message_type"]),
      timeSent: DateTime.parse(json["time_sent"] ?? ""),
      chatSessionId: json["chat_session_id"],
      citations: json["citations"],
      refinedAnswerImprovement: json["refined_answer_improvement"],
      error: json["error"],
    );
  }

  Map<String, dynamic> toJson() => {
    "message_id": messageId,
    "parent_message": parentMessage,
    "latest_child_message": latestChildMessage,
    "message": message,
    "message_type": 'user',
    "time_sent": timeSent?.toIso8601String(),
    "chat_session_id": chatSessionId,
    "citations": citations,
    "refined_answer_improvement": refinedAnswerImprovement,
    "error": error,
  };

  @override
  String toString(){
    return "$messageId, $parentMessage, $latestChildMessage, $message, $messageType, $timeSent, $chatSessionId, $citations, $refinedAnswerImprovement, $error, ";
  }
}

enum MessageType {
  user, assistant, system;
  static MessageType fromJson(String type) {
    return switch(type) {
      'user' => MessageType.user,
      'assistant' => MessageType.assistant,
      'system' => MessageType.system,
      // TODO: Handle this case.
      String() => MessageType.system,
    };
  }
}