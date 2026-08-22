import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

export '../../core/networking/allowlist_state.dart' show notAllowlistedProvider;

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Live Firebase auth state — null when signed out.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The signed-in family member's id (Firebase UID, doubling as our local
/// `users.id`). Every DAO/repository call is scoped by this — no query path
/// anywhere accepts a foreign user id (hard constraint #5). Null while
/// signed out; screens below `AuthGate` can assume it's non-null.
final currentUserIdProvider = Provider<String?>((ref) {
  final asyncUser = ref.watch(authStateChangesProvider);
  return asyncUser.maybeWhen(data: (user) => user?.uid, orElse: () => null);
});
