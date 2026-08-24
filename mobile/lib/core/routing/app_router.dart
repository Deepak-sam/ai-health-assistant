import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_screen.dart';
import '../../features/alerts/create_alert_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/history_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/nutrition/nutrition_confirm_screen.dart';
import '../../features/nutrition/nutrition_text_entry_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'navigator_key.dart';
import 'scaffold_with_nav.dart';

/// go_router configuration. Chat is the initial location — this app is
/// chat-first, never dashboard-first (hard constraint #1). Bottom nav order
/// is fixed: Chat, History, Insights, Settings.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/chat',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
              routes: [
                GoRoute(
                  path: ':conversationId',
                  builder: (context, state) => ChatScreen(
                    conversationId: state.pathParameters['conversationId'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'alerts',
                  builder: (context, state) => const AlertsScreen(),
                  routes: [
                    GoRoute(path: 'create', builder: (context, state) => const CreateAlertScreen()),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Modal-ish flows pushed on top of the shell rather than living in the
    // bottom nav (nutrition logging is initiated from Chat, not its own tab).
    GoRoute(
      path: '/nutrition/text-entry',
      builder: (context, state) => const NutritionTextEntryScreen(),
    ),
    GoRoute(
      path: '/nutrition/confirm',
      // `extra` carries the NutritionResult + source ('photo' | 'text') from
      // the screen that produced it — see NutritionConfirmArgs.
      builder: (context, state) => NutritionConfirmScreen(args: state.extra as NutritionConfirmArgs),
    ),
  ],
);
