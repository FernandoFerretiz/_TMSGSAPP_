import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../data/chatbot_service.dart';
import '../models/chat_message.dart';

class ChatBotController extends GetxController {
  final ChatBotService _service;

  ChatBotController(this._service);

  // Estado del flujo en el que el bot pide la fecha/hora de la cita: en
  // este paso mostramos un selector nativo en vez de solo texto libre.
  static const _appointmentWaitingFor = 'assignment_appointment';

  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isSending = false.obs;
  final RxBool isLoading = false.obs;
  final RxnString waitingFor = RxnString();

  bool get isAwaitingAppointment => waitingFor.value == _appointmentWaitingFor;

  @override
  void onInit() {
    super.onInit();
    _loadStart();
  }

  Future<void> _loadStart() async {
    isLoading.value = true;
    try {
      final result = await _service.start();
      waitingFor.value = result.waitingFor;
      if (result.reply.isNotEmpty) {
        messages.add(ChatMessage(text: result.reply, fromUser: false));
      }
    } catch (_) {
      messages.add(ChatMessage(
        text: 'No pude conectar con el asistente. Intenta de nuevo.',
        fromUser: false,
      ));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending.value) return;

    messages.add(ChatMessage(text: trimmed, fromUser: true));
    isSending.value = true;
    try {
      final result = await _service.sendMessage(trimmed);
      waitingFor.value = result.waitingFor;
      if (result.reply.isNotEmpty) {
        messages.add(ChatMessage(text: result.reply, fromUser: false));
      }
    } catch (_) {
      messages.add(ChatMessage(
        text: 'No pude enviar tu mensaje. Intenta de nuevo.',
        fromUser: false,
      ));
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendAppointment(DateTime dateTime) async {
    await sendText(DateFormat('yyyy-MM-dd HH:mm').format(dateTime));
  }

  Future<void> sendFile(XFile file) async {
    if (isSending.value) return;

    messages.add(ChatMessage(text: 'Archivo enviado: ${file.name}', fromUser: true));
    isSending.value = true;
    try {
      final result = await _service.sendDocument(file);
      waitingFor.value = result.waitingFor;
      if (result.reply.isNotEmpty) {
        messages.add(ChatMessage(text: result.reply, fromUser: false));
      }
    } catch (_) {
      messages.add(ChatMessage(
        text: 'No pude enviar el archivo. Intenta de nuevo.',
        fromUser: false,
      ));
    } finally {
      isSending.value = false;
    }
  }
}
