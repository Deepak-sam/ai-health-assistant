import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/chat_models.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/repositories/health_repository.dart';
import '../auth/auth_state.dart';
import 'context_builder.dart';

class ChatUiState {
  const ChatUiState({
    this.conversationId,
    this.sending = false,
    this.error,
    this.lastSuggestedFollowups = const [],
    this.lastSafetyFlag,
  });

  final String? conversationId;
  final bool sending;
  final String? error;
  final List<String> lastSuggestedFollowups;
  final String? lastSafetyFlag;

  ChatUiState copyWith({
    String? conversationId,
    bool? sending,
    String? error,
    List<String>? lastSuggestedFollowups,
    String? lastSafetyFlag,
    bool clearError = false,
  }) {
    return ChatUiState(
      conversationId: conversationId ?? this.conversationId,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
      lastSuggestedFollowups: lastSuggestedFollowups ?? this.lastSuggestedFollowups,
      lastSafetyFlag: lastSafetyFlag,
    );
  }
}

/// Orchestrates one chat conversation: resolving/creating the conversation
/// row, building the pre-computed context bundle (never raw DB dumps —
/// ARCHITECTURE.md §6/§9), and sending the turn. Message content itself is
/// rendered from `chatRepository.watchMessages` (a live Drift stream), not
/// from state here — this controller only tracks send-in-flight/error UI
/// state and the last response's follow-ups/safety flag.
class ChatController extends StateNotifier<ChatUiState> {
  ChatController(this._ref, String? initialConversationId) : super(ChatUiState(conversationId: initialConversationId)) {
    if (initialConversationId == null) {
      _resolveDefaultConversation();
    }
  }

  final Ref _ref;

  Future<void> _resolveDefaultConversation() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    final repo = _ref.read(chatRepositoryProvider);
    final existing = await repo.getConversations(userId);
    final id = existing.isNotEmpty ? existing.first.id : await repo.ensureConversation(userId);
    if (mounted) state = state.copyWith(conversationId: id);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = state.copyWith(sending: true, clearError: true);
    try {
      final chatRepo = _ref.read(chatRepositoryProvider);
      final conversationId = state.conversationId ?? await chatRepo.ensureConversation(userId);
      if (state.conversationId == null) state = state.copyWith(conversationId: conversationId);

      final contextBuilder = ChatContextBuilder(_ref.read(healthRepositoryProvider));
      final context = await contextBuilder.build(userId: userId);
      final priorMessages = await chatRepo.getRecentMessages(userId: userId, conversationId: conversationId);
      final summary = contextBuilder.buildConversationSummary(priorMessages);

      final ChatResponse response = await chatRepo.sendMessage(
        userId: userId,
        conversationId: conversationId,
        userMessage: trimmed,
        context: context,
        conversationSummary: summary,
      );

      state = state.copyWith(
        sending: false,
        lastSuggestedFollowups: response.suggestedFollowups,
        lastSafetyFlag: response.safetyFlag,
      );
    } catch (e) {
      state = state.copyWith(sending: false, error: 'Something went wrong sending that message.');
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatUiState, String?>((ref, conversationId) {
  return ChatController(ref, conversationId);
});
