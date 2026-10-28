/// Eşleşme içi tek mesaj (docs/mvp.md §4.6: yalnızca yazılı)
class Message {
  const Message({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int matchId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      matchId: json['match_id'] as int,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
