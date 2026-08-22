import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_state.dart';
import 'sign_in_screen.dart';

/// Wraps the whole app (used in `MaterialApp.router`'s `builder`). Shows:
///  - a splash while Firebase resolves the initial auth state,
///  - [SignInScreen] when signed out,
///  - a non-dismissible allowlist error screen when the backend has told us
///    (via a `403 not_allowlisted` on some API call) that this Firebase
///    account isn't authorized for this family instance,
///  - otherwise, the routed app content (`child`).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final notAllowlisted = ref.watch(notAllowlistedProvider);

    return authState.when(
      loading: () => const _Splash(),
      error: (_, __) => const SignInScreen(),
      data: (user) {
        if (user == null) return const SignInScreen();
        if (notAllowlisted) return const _NotAllowlistedScreen();
        return child;
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _NotAllowlistedScreen extends ConsumerWidget {
  const _NotAllowlistedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 40, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 20),
              Text('Account not authorized', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                // Matches API_SPEC.md's not_allowlisted error message.
                'This account is not authorized for this family instance. '
                'Ask the family admin to add your email to the allowlist.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
                  ),
                  onPressed: () async {
                    ref.read(notAllowlistedProvider.notifier).state = false;
                    await ref.read(authRepositoryProvider).signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
