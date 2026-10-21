import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';

class ChatBotReply {
  final String reply;
  final String? waitingFor;

  const ChatBotReply({required this.reply, this.waitingFor});

  factory ChatBotReply.fromResponse(Map<String, dynamic> data) {
    return ChatBotReply(
      reply: data['reply'] as String? ?? '',
      waitingFor: data['waiting_for'] as String?,
    );
  }
}

class ChatBotService {
  final ApiClient _apiClient;

  ChatBotService(this._apiClient);

  Future<ChatBotReply> start() async {
    final response = await _apiClient.dio.post('/api/mobile/chatbot/start');
    return ChatBotReply.fromResponse(response.data as Map<String, dynamic>);
  }

  Future<ChatBotReply> sendMessage(String text) async {
    final response = await _apiClient.dio.post(
      '/api/mobile/chatbot/message',
      data: {'text': text},
    );
    return ChatBotReply.fromResponse(response.data as Map<String, dynamic>);
  }

  Future<ChatBotReply> sendDocument(XFile file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    });

    final response = await _apiClient.dio.post(
      '/api/mobile/chatbot/document',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ChatBotReply.fromResponse(response.data as Map<String, dynamic>);
  }
}
