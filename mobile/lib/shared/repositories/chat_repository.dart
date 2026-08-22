import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/daos/conversations_dao.dart';
import '../../core/networking/dio_client.dart';
import '../models/chat_models.dart';

/// Talks to `POST /chat` (API_SPEC.md) and persists the turn into
/// `conversations`/`messages`. The `ChatContext` passed in must already be
/// fully pre-computed (baselines, trends, %-change) by the caller — this
/// repository never computes statistics itself, it only transports them
/// (hard constraint #3).
class ChatRepository {
  ChatRepository({required Dio dio, required ConversationsDao dao})
      : _dio = dio,
        _dao = dao;

  final Dio _dio;
  final ConversationsDao _dao;
  final _uuid = const Uuid();

  Future<String> ensureConversation(String userId, {String? conversationId}) async {
    if (conversationId != null) return conversationId;
    final id = _uuid.v4();
    final now = DateTime.now();
    await _dao.createConversation(db.ConversationsCompanion.insert(
      id: id,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  Future<ChatResponse> sendMessage({
    required String userId,
    required String conversationId,
    required String userMessage,
    required ChatContext context,
    required String conversationSummary,
  }) async {
    // Persist the user's turn immediately so it shows up even if the
    // network call fails.
    await _dao.insertMessage(db.MessagesCompanion.insert(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: 'user',
      content: userMessage,
      relatedQueryJson: Value(jsonEncode(context.toJson())),
      createdAt: DateTime.now(),
    ));
    await _dao.setTitleIfMissing(
      userId: userId,
      conversationId: conversationId,
      title: userMessage.length > 60 ? '${userMessage.substring(0, 60)}…' : userMessage,
    );

    final recent = await _dao.getRecentMessages(userId: userId, conversationId: conversationId);
    final request = ChatRequest(
      message: userMessage,
      context: context,
      conversationSummary: conversationSummary,
      recentMessages: recent
          .take(recent.length > 1 ? recent.length - 1 : 0) // exclude the message we just inserted
          .map((m) => ChatMessageSummary(role: m.role, content: m.content))
          .toList(),
    );

    late final ChatResponse chatResponse;
    try {
      final response = await _dio.post<Map<String, dynamic>>('/chat', data: request.toJson());
      chatResponse = ChatResponse.fromJson(response.data!);
    } on DioException catch (e) {
      final apiError = mapDioError(e);
      // Surface a graceful assistant-style error bubble rather than losing
      // the turn entirely — the message the user sent is already saved.
      chatResponse = ChatResponse(
        reply: "I couldn't reach the server (${apiError.message}). Your message was saved — try again shortly.",
        cards: const [],
        suggestedFollowups: const [],
        safetyFlag: null,
      );
    }

    await _dao.insertMessage(db.MessagesCompanion.insert(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: 'assistant',
      content: chatResponse.reply,
      cardJson: Value(chatResponse.cards.isEmpty ? null : jsonEncode(chatResponse.cards.map(_cardToJson).toList())),
      createdAt: DateTime.now(),
    ));
    await _dao.touchConversation(userId: userId, conversationId: conversationId);

    return chatResponse;
  }

  Map<String, dynamic> _cardToJson(ChatCard c) =>
      {'type': c.type, 'title': c.title, 'subtitle': c.subtitle, 'metrics': c.metrics};

  Stream<List<db.Message>> watchMessages({required String userId, required String conversationId}) {
    return _dao.watchMessages(userId: userId, conversationId: conversationId);
  }

  Future<List<db.Message>> getRecentMessages({required String userId, required String conversationId, int limit = 6}) {
    return _dao.getRecentMessages(userId: userId, conversationId: conversationId, limit: limit);
  }

  Future<List<db.Conversation>> getConversations(String userId) => _dao.getConversations(userId);

  Stream<List<db.Conversation>> watchConversations(String userId) => _dao.watchConversations(userId);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final database = ref.watch(db.appDatabaseProvider);
  return ChatRepository(dio: ref.watch(dioProvider), dao: database.conversationsDao);
});
