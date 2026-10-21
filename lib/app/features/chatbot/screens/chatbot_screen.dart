import '../../../core/design/sx_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../trips/widgets/photo_source_sheet.dart';
import '../controllers/chatbot_controller.dart';
import '../models/chat_message.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final _controller = Get.find<ChatBotController>();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    _textController.clear();
    await _controller.sendText(text);
    _scrollToBottom();
  }

  Future<void> _attach() async {
    final files = await showPhotoSourceSheet(context);
    if (files.isEmpty) return;
    await _controller.sendFile(files.first);
    _scrollToBottom();
  }

  Future<void> _pickAppointment() async {
    DateTime selected = DateTime.now();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    initialDateTime: selected,
                    minimumDate: DateTime.now().subtract(const Duration(days: 1)),
                    use24hFormat: true,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _controller.sendAppointment(selected);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: const Text('Asistente Sultan')),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _controller.messages.length,
                itemBuilder: (context, index) =>
                    _MessageBubble(message: _controller.messages[index]),
              );
            }),
          ),
          Obx(() => _controller.isSending.value
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const SizedBox.shrink()),
          Obx(() => _InputBar(
                controller: _textController,
                onSend: _sendText,
                onAttach: _attach,
                onPickAppointment: _controller.isAwaitingAppointment
                    ? _pickAppointment
                    : null,
              )),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align =
        message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = message.fromUser ? AppColors.royalBlue : Colors.white;
    final textColor = message.fromUser ? Colors.white : AppColors.textDark;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback? onPickAppointment;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.onPickAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.fieldBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded,
                  color: AppColors.royalBlue),
              onPressed: onAttach,
            ),
            if (onPickAppointment != null)
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded,
                    color: AppColors.royalBlue),
                tooltip: 'Seleccionar fecha y hora de la cita',
                onPressed: onPickAppointment,
              ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.royalBlue),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
