import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' as db;
import '../../shared/models/nutrition_models.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/widgets/chat_bubble.dart';
import '../../shared/widgets/health_card.dart';
import '../../shared/widgets/nutrition_card.dart';
import '../../shared/widgets/quick_action_chip.dart';
import '../auth/auth_state.dart';
import 'chat_controller.dart';
import 'widgets/chat_input_bar.dart';

/// Chat — the app's default/home screen (hard constraint #1: never
/// dashboard-first). Also reused read-only-ish for continuing a past
/// conversation opened from History, via [conversationId].
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, this.conversationId});

  final String? conversationId;

  static const _quickActions = [
    'How did I sleep?',
    'Should I train today?',
    'Log a meal',
    'How are my steps trending?',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final uiState = ref.watch(chatControllerProvider(conversationId));
    final controller = ref.read(chatControllerProvider(conversationId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: userId == null || uiState.conversationId == null
                ? const Center(child: CircularProgressIndicator())
                : _MessageList(userId: userId, conversationId: uiState.conversationId!),
          ),
          if (uiState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(uiState.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (uiState.lastSuggestedFollowups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: uiState.lastSuggestedFollowups
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: QuickActionChip(label: f, onTap: () => controller.sendMessage(f)),
                          ))
                      .toList(),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickActions
                      .map((label) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: QuickActionChip(label: label, onTap: () => controller.sendMessage(label)),
                          ))
                      .toList(),
                ),
              ),
            ),
          ChatInputBar(sending: uiState.sending, onSend: controller.sendMessage),
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.userId, required this.conversationId});

  final String userId;
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(_messagesStreamProvider((userId: userId, conversationId: conversationId)));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load messages.')),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Ask about your sleep, recovery, training, or log a meal to get started.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return _MessageBubble(message: message);
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final db.Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    Widget? trailing;
    if (message.cardJson != null) {
      try {
        final cards = jsonDecode(message.cardJson!) as List<dynamic>;
        trailing = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.map<Widget>((c) => _renderCard(c as Map<String, dynamic>)).toList(),
        );
      } catch (_) {
        trailing = null;
      }
    }
    return ChatBubble(
      text: message.content,
      isUser: isUser,
      isSafetyFlag: message.safetyFlag != null,
      trailing: trailing,
    );
  }

  Widget _renderCard(Map<String, dynamic> card) {
    final type = card['type'] as String? ?? 'generic';
    if (type == 'nutrition') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: NutritionCard(
          result: NutritionResult(
            mealName: card['title'] as String? ?? 'Meal',
            items: const [],
            totalCalories: (card['metrics']?['calories'] as num?)?.toDouble() ?? 0,
            proteinG: (card['metrics']?['protein_g'] as num?)?.toDouble() ?? 0,
            carbsG: (card['metrics']?['carbs_g'] as num?)?.toDouble() ?? 0,
            fatG: (card['metrics']?['fat_g'] as num?)?.toDouble() ?? 0,
          ),
          confidenceVisible: false,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HealthCard(
        title: card['title'] as String? ?? '',
        subtitle: card['subtitle'] as String?,
        metrics: (card['metrics'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

final _messagesStreamProvider =
    StreamProvider.family<List<db.Message>, ({String userId, String conversationId})>((ref, args) {
  return ref.watch(chatRepositoryProvider).watchMessages(userId: args.userId, conversationId: args.conversationId);
});
