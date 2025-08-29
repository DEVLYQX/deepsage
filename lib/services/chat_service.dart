import 'dart:async';
import 'dart:ui';
import 'package:deepsage/models/chat_session.dart';
import 'package:deepsage/services/api_service.dart';
import 'package:deepsage/services/storage_service.dart';
import 'package:logger/logger.dart';

class ChatServices {
  ChatServices._();
  
  static final instance = ChatServices._();
  final _api = ApiService.instance;
  
  Future<void> getChatSessions () async {
    try {
      final result = _api.get('/chat/get-user-chat-sessions', isChat: true);
    } catch (e, s) {
      Logger().e(e, stackTrace: s);
    }
  }

  Future<void> createNewSession() async {
    try {
      final result = ApiService.instance.post('/chat/create-chat-session', {
        "persona_id": 2,
        "description": "Chat 1"
      }, isChat: true);
    } catch (e, s) {
      Logger().e(e, stackTrace: s);
    }
  }
}

class ChatService {

  ChatService._();

  static final instance = ChatService._();

  final _api = ApiService.instance;
  String chatId = ''; // fb446bb9-8006-44a4-a627-ca4d0663a62c
  
  final _chatMessagesController = StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get chatMessagesStream => _chatMessagesController.stream;
  List<ChatMessage> chatMessages = [];

  // Send a message
  Future<void> sendMessage(String content, {void Function()? onDone, VoidCallback? onError, VoidCallback? setTyping}) async {
    final token = await StorageService.instance.cookie;
    if (token == null) {
      throw Exception('Not authenticated');
    }
    // Logger().i('AI is thinking(${'<status>Requesting the knowledge base</status>'.replaceAllMapped(RegExp(r'(?<=<status>)(.*?)(?=</status>)'),(match) => match.group(1) ?? '',)}). Skip');
    // Logger().i('AI is thinking(${'<status>Requesting the knowledge base</status>'.replaceAll('<status>', '')}). Skip');
    try {
      // add user message to the chat first
      chatMessages.add(ChatMessage(message: content, messageType: MessageType.user, timeSent: DateTime.now(), chatSessionId: chatId));
      _chatMessagesController.add(List.unmodifiable(chatMessages));

      // send message to server as stream
      final stream = _api.handleSSEStream('/chat/send-message', body: {
        "alternate_assistant_id": 8,
        "message": content,
        "chat_session_id": chatId,
        "parent_message_id": null,
        "file_descriptors": [],
        "user_file_ids": [],
        "user_folder_ids": [],
        "regenerate": false,
        "prompt_id": null,
        "retrieval_options": {
          "run_search": "auto",
          "real_time": true,
          "filters": {
            "source_type": null,
            "document_set": null,
            "time_cutoff": null,
            "tags": [],
            "user_file_ids": []
          }
        },
        "search_doc_ids": [],
        "prompt_override": {
          "system_prompt": systemPrompt
        },
        "llm_override": {
          "temperature": 0.5,
          "model_provider": "staging_mastergpt_forex",
          "model_version": "openai/forex_gpt-4.1-2025-04-14"
        },
        "use_agentic_search": false
      });

      // listen to stream and check responses
      stream.listen((event) {
          Logger().i("Got SSE event(${event.runtimeType}): $event");
          if(event is Map<String, dynamic>) {
            if(event case {'answer_piece': final String answer} ) {
              setTyping?.call();
              if(answer.trim().isEmpty) {
                Logger().i('Answer is empty. Skip');
              } else if(answer.trim().contains('<status>') || answer.contains('</status>')) {
                Logger().i('AI is thinking($answer). Skip');
              } else {
                Logger().i('AI response ready: $answer');
              }
            } else if(event case {'message_id': final int messageID, "parent_message": final int parent, "message_type": final String msgType}) {
              Logger().i('Adding ai response');
              // add ai response on here once the data pattern in else if is matched is matched
              final reply = ChatMessage.fromJson(event);
              chatMessages.add(reply);
              _chatMessagesController.add(List.unmodifiable(chatMessages));
            } else {
              Logger().i('NO answer piece');
            }
          }
        },
        onError: (e, s) {
          Logger().e("Stream Error: $e", stackTrace: s);
          onError?.call();
        },
        onDone: onDone,
      );


      // d34bfd07-b40f-45fe-a7c2-02bca2dbfd70
      // final result = await _api.post('/chat/send-message', {
      //   "alternate_assistant_id": 8,
      //   "message": content,
      //   "chat_session_id": chatId,
      //   "parent_message_id": null,
      //   "file_descriptors": [],
      //   "user_file_ids": [],
      //   "user_folder_ids": [],
      //   "regenerate": false,
      //   "prompt_id": null,
      //   "retrieval_options": {
      //     "run_search": "auto",
      //     "real_time": true,
      //     "filters": {
      //       "source_type": null,
      //       "document_set": null,
      //       "time_cutoff": null,
      //       "tags": [],
      //       "user_file_ids": []
      //     }
      //   },
      //   "search_doc_ids": [],
      //   "prompt_override": {
      //     "system_prompt": systemPrompt
      //   },
      //   "llm_override": {
      //     "temperature": 0.5,
      //     "model_provider": "staging_mastergpt_forex",
      //     "model_version": "openai/forex_gpt-4.1-2025-04-14"
      //   },
      //   "use_agentic_search": false
      // }, isChat: true);
      // if(result.isSuccess) {
      //   print(result.data.runtimeType);
      // }
    } catch (e) {
      Logger().e('Send message error: $e');
      // _messagesController.addError(e);
    }
  }

  // Get chat history
  Future<void> getChatHistory() async {
    final id = await StorageService.instance.sessionId;
    if(id == null) {
      Logger().i('Creating new session');
      final result = await ApiService.instance.post('/chat/create-chat-session', {
        "persona_id": 2,
        "description": "description"
      }, isChat: true);

      if(result.isSuccess) {
        chatId = result.data['chat_session_id'];
        Logger().i('CHAT ID: $chatId');
        StorageService.instance.saveLastSessionId(chatId);
      }
    } else {
      Logger().i('Getting chats from last session');
      final res = await _api.get('/chat/get-chat-session/$id', isChat: true);
      if(res.isSuccess) {
        chatId = id;
        final chat = ChatSession.fromJson(res.data);
        final messages = chat.messages;
        messages.sort((a, b) {
          final dateA = a.timeSent;
          final dateB = b.timeSent;
          return dateA.compareTo(dateB);
        });
        chatMessages.addAll(messages);
        _chatMessagesController.add(List.unmodifiable(chatMessages));
        Logger().i(chat.toString());
      }
    }


    // await _api.get('/chat/get-chat-session/${'dc8d8dac-4f38-46cb-9ffc-baa3bed7a24d'}', isChat: true);

  }


}



const String systemPrompt = "<info>eyJhbGciOiJIUzI1NiJ9.eyJkYXRhIjoie1widXVpZFwiOm51bGwsXCJ1c2VyX2lkXCI6XCI3YTllMmUzYS05OWZhLTQ1MzYtYWRhNy1iOTI5MzY1MjE3YTVcIixcImV4dGVybmFsX2lkXCI6NTU1OTIzLFwiYXNzaXN0YW50XCI6XCJjcnlwdG9cIixcInBlcm1pc3Npb25zXCI6e1wiU1VCU0NSSVBUSU9OX0ZYX01BR0lDX0JSRUFLRVZFTlwiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiU1VCU0NSSVBUSU9OX0ZYX01BR0lDX1RSQUlMSU5HX1NUT1BcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9GWF9NQUdJQ19QQVJUSUFMX1RBS0VfUFJPRklUXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJNQVNURVJHUFRfQk9UX0FTU0lTVEFOVF9BTExPV0VEXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX1BUX0tVQ09JTl9BQ0NFU1NcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9DUllQVE9fUFRfQllCSVRfQUNDRVNTXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX1BUX0JJTkFOQ0VfQUNDRVNTXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fTUFYX0RFTU9fQUNDT1VOVFNcIjp7XCJ2YWx1ZVwiOi0xLFwiZGF0YVR5cGVcIjpcIm51bWJlclwifSxcIlNVQlNDUklQVElPTl9DUllQVE9fUFRfRVhUUkFfRVhDSEFOR0VTXCI6e1widmFsdWVcIjoyLFwiZGF0YVR5cGVcIjpcIm51bWJlclwifSxcIlNVQlNDUklQVElPTl9PTU5JX0FJXCI6e1widmFsdWVcIjoxMCxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX0FJX0JBU0tFVFNcIjp7XCJ2YWx1ZVwiOjUsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0NSWVBUT19BSV9CQVNLRVRTX1JFQkFMQU5DRVwiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiU1VCU0NSSVBUSU9OX0NSWVBUT19BSV9CQVNLRVRTX0NVU1RPTV9DT0lOU19QUkVTRVRcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9DUllQVE9fQUlfQkFTS0VUU19CQUNLVEVTVElOR19VSV9BTExPV0VEXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX0FJX0JBU0tFVFNfQ1VTVE9NX1RIUkVTSE9MRF9SRUJBTEFOQ0lOR19BTExPV0VEXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX0FJX0JBU0tFVFNfUkVCQUxBTkNJTkdfU0NIRURVTEVcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9DUllQVE9fUFRfS1JBS0VOX0FDQ0VTU1wiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiU1VCU0NSSVBUSU9OX0NSWVBUT19QVF9CSVRHRVRfQUNDRVNTXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX1BUX0JJTkFOQ0VVU0RNX0FDQ0VTU1wiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiU1VCU0NSSVBUSU9OX0NSWVBUT19GVVRVUkVTX0FDQ0VTU1wiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiVFJBRElOR19WSUVXX0FEVkFOQ0VEXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJUUkFESU5HX1ZJRVdfQUxFUlRTXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJGWF9QRVJTT05BTF9XRUJIT09LX0FMRVJUU19BQ0NFU1NcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9GWF9CQUNLVEVTVF9EQUlMWV9MSU1JVFwiOntcInZhbHVlXCI6NixcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fRlhfQkFDS1RFU1RfSElTVE9SSUNBTF9ERVBUSFwiOntcInZhbHVlXCI6MzY1LFwiZGF0YVR5cGVcIjpcIm51bWJlclwifSxcIlNVQlNDUklQVElPTl9NQVhfRVhDSEFOR0VTXCI6e1widmFsdWVcIjotMSxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJESVNBQkxFX0FVVE9TVE9QX0JPVFNcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9CQVNFX09SREVSX0FNT1VOVF9JTl9QRVJDRU5UXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fRENBX0FJXCI6e1widmFsdWVcIjoyMCxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fQ1JZUFRPX1BUX09NTklfQUlcIjp7XCJ2YWx1ZVwiOjIsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0dSSURfQUlcIjp7XCJ2YWx1ZVwiOjI1LFwiZGF0YVR5cGVcIjpcIm51bWJlclwifSxcIlNVQlNDUklQVElPTl9BQ1RJVkVfU01BUlRfVFJBREVTXCI6e1widmFsdWVcIjotMSxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fUE9SVEZPTElPX0FDQ0VTU1wiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiREVFUFNBR0VfTE9HSU5fQUxMT1dFRFwiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiREVFUFNBR0VfVk9JQ0VfQUxMT1dFRFwiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiREVFUFNBR0VfU0FHRUJJVF9BTExPV0VEXCI6e1widmFsdWVcIjp0cnVlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJERUVQU0FHRV9TQUdFQklUX1BMVVNfQUxMT1dFRFwiOntcInZhbHVlXCI6dHJ1ZSxcImRhdGFUeXBlXCI6XCJib29sZWFuXCJ9LFwiREVFUFNBR0VfU0FHRUZYX0FMTE9XRURcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9CUk9LRVJcIjp7XCJ2YWx1ZVwiOjUsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0VYUEVSVF9BRFZJU09SU1wiOntcInZhbHVlXCI6MjAsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0ZYX1BFUlNPTkFMX1dFQkhPT0tfQUxFUlRTX01BWF9FWFBFUlRTXCI6e1widmFsdWVcIjoxNyxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fRlhfTUFHSUNfQUNUSVZFX1NNQVJUX1RSQURFU1wiOntcInZhbHVlXCI6MjAsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0ZYX09SREVSX1NFU1NJT05fTUFOQUdFTUVOVFwiOntcInZhbHVlXCI6ZmFsc2UsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9JTkRJQ0VTX1BST1ZJREVSU19BQ0NFU1NcIjp7XCJ2YWx1ZVwiOmZhbHNlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJTVUJTQ1JJUFRJT05fU1lOVEhFVElDX1BST1ZJREVSU19BQ0NFU1NcIjp7XCJ2YWx1ZVwiOmZhbHNlLFwiZGF0YVR5cGVcIjpcImJvb2xlYW5cIn0sXCJESVNBQkxFX0FVVE9TVE9QX0ZYX0JPVFNcIjp7XCJ2YWx1ZVwiOnRydWUsXCJkYXRhVHlwZVwiOlwiYm9vbGVhblwifSxcIlNVQlNDUklQVElPTl9GWF9QRVJTT05BTF9XRUJIT09LX0FMRVJUU19NQVhfRVhQRVJUU19FWFRFTkRFUlwiOntcInZhbHVlXCI6MTIsXCJkYXRhVHlwZVwiOlwibnVtYmVyXCJ9LFwiU1VCU0NSSVBUSU9OX0VYUEVSVF9BRFZJU09SU19FWFRFTkRFUlwiOntcInZhbHVlXCI6OCxcImRhdGFUeXBlXCI6XCJudW1iZXJcIn0sXCJTVUJTQ1JJUFRJT05fQlJPS0VSX0VYVEVOREVSXCI6e1widmFsdWVcIjoyLFwiZGF0YVR5cGVcIjpcIm51bWJlclwifSxcIkJBTEFOQ0VfUkVBRFwiOntcImRhdGFUeXBlXCI6XCJib29sZWFuXCIsXCJ2YWx1ZVwiOnRydWV9LFwiRVhDSEFOR0VfREVMRVRFXCI6e1wiZGF0YVR5cGVcIjpcImJvb2xlYW5cIixcInZhbHVlXCI6dHJ1ZX19fSJ9.BhAZWW-BsjA4zeE_EJ7vGe2FRjdbPo4ls6Igwr_p0bU</info>";


// {
//      "message_id": 2473,
//      "parent_message": 2476,
//      "latest_child_message": 2476,
//      "message": "Hello",
//      "message_type": "user",
//      "time_sent": "2025-08-28T19:27:04.878137Z",
//      "chat_session_id": "fb446bb9-8006-44a4-a627-ca4d0663a62c",
//      "citations": null,
//      "sub_questions": []
//      "files": []
//      "tool_call": null,
//      "refined_answer_improvement": null,
//      "error": null
// }

/// fdccvv
///

    // {
    //      "chat_session_id": "dc8d8dac-4f38-46cb-9ffc-baa3bed7a24d",
    //      "description": "description",
    //      "persona_id": 2,
    //      "persona_name": "Onyx doc searcher",
    //      "persona_icon_color": "#6FFF8D",
    //      "persona_icon_shape": 24182,
    //      "messages": []
    //      "time_created": "2025-08-28T20:29:42.379391Z",
    //      "shared_status": "private",
    //      "current_alternate_model": null,
    //      "current_temperature_override": null
    // }
///
