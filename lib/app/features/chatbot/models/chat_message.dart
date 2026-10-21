class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime sentAt;

  ChatMessage({
    required this.text,
    required this.fromUser,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}
