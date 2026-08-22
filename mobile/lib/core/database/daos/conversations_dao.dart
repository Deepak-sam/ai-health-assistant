import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/conversations_table.dart';
import '../tables/messages_table.dart';

part 'conversations_dao.g.dart';

/// Conversations belong to a user directly; messages are scoped to a
/// conversation, so every message query here joins back through
/// conversations to keep the user_id filter (hard constraint #5) even
/// though the messages table itself only stores conversation_id.
@DriftAccessor(tables: [Conversations, Messages])
class ConversationsDao extends DatabaseAccessor<AppDatabase> with _$ConversationsDaoMixin {
  ConversationsDao(super.db);

  Future<void> createConversation(ConversationsCompanion conversation) {
    return into(conversations).insert(conversation);
  }

  Future<List<Conversation>> getConversations(String userId) {
    return (select(conversations)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<Conversation>> watchConversations(String userId) {
    return (select(conversations)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<void> touchConversation({required String userId, required String conversationId}) {
    return (update(conversations)..where((t) => t.userId.equals(userId) & t.id.equals(conversationId)))
        .write(ConversationsCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> setTitleIfMissing({
    required String userId,
    required String conversationId,
    required String title,
  }) async {
    final existing = await (select(conversations)
          ..where((t) => t.userId.equals(userId) & t.id.equals(conversationId)))
        .getSingleOrNull();
    if (existing != null && (existing.title == null || existing.title!.isEmpty)) {
      await (update(conversations)..where((t) => t.userId.equals(userId) & t.id.equals(conversationId)))
          .write(ConversationsCompanion(title: Value(title)));
    }
  }

  Future<void> insertMessage(MessagesCompanion message) => into(messages).insert(message);

  /// Verifies [conversationId] belongs to [userId] before returning its
  /// messages, so a caller can never read another family member's chat by
  /// guessing a conversation id.
  Future<List<Message>> getMessages({required String userId, required String conversationId}) async {
    final owns = await (select(conversations)
          ..where((t) => t.userId.equals(userId) & t.id.equals(conversationId)))
        .getSingleOrNull();
    if (owns == null) return const [];
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<Message>> watchMessages({required String userId, required String conversationId}) {
    final query = select(messages).join([
      innerJoin(
        conversations,
        conversations.id.equalsExp(messages.conversationId) & conversations.userId.equals(userId),
      ),
    ])
      ..where(messages.conversationId.equals(conversationId))
      ..orderBy([OrderingTerm.asc(messages.createdAt)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(messages)).toList());
  }

  /// Recent messages for [conversationId] (most recent last), capped at
  /// [limit] — used to build the `recent_messages` slice of the /chat
  /// context bundle without sending full history (ARCHITECTURE.md §6/§9).
  Future<List<Message>> getRecentMessages({
    required String userId,
    required String conversationId,
    int limit = 6,
  }) async {
    final owns = await (select(conversations)
          ..where((t) => t.userId.equals(userId) & t.id.equals(conversationId)))
        .getSingleOrNull();
    if (owns == null) return const [];
    final rows = await (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.reversed.toList();
  }
}
