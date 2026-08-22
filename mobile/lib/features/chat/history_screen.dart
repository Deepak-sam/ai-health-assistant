import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart' as db;
import '../../shared/repositories/chat_repository.dart';
import '../auth/auth_state.dart';

/// Lists past conversations (History tab). Tapping one opens it in
/// [ChatScreen] via `/history/:conversationId`.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final conversationsAsync = ref.watch(_conversationsStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load history.')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Text('No conversations yet.', style: Theme.of(context).textTheme.bodyMedium),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, index) {
              final c = conversations[index];
              return ListTile(
                title: Text(c.title?.isNotEmpty == true ? c.title! : 'Conversation'),
                subtitle: Text(DateFormat.yMMMd().add_jm().format(c.updatedAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/history/${c.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

final _conversationsStreamProvider = StreamProvider.family<List<db.Conversation>, String>((ref, userId) {
  return ref.watch(chatRepositoryProvider).watchConversations(userId);
});
