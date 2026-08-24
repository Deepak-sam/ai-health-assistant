import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// A single chat message bubble. User messages align right with a muted
/// fill; assistant messages align left with a bordered card — the familiar
/// calm, minimal chat layout the product brief asks for (no avatars, no
/// "typing as a persona" styling).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isSafetyFlag = false,
    this.trailing,
  });

  final String text;
  final bool isUser;
  /// Renders a distinct, non-dismissible style for safety_flag replies
  /// (API_SPEC.md `/chat` response, ARCHITECTURE.md §9/§24).
  final bool isSafetyFlag;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isSafetyFlag
        ? AppColors.danger.withValues(alpha: 0.12)
        : isUser
            ? (isDark ? AppColors.darkBubbleUser : AppColors.lightBubbleUser)
            : (isDark ? AppColors.darkBubbleAssistant : AppColors.lightBubbleAssistant);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: isUser
            ? null
            : Border.all(
                color: isSafetyFlag ? AppColors.danger.withValues(alpha: 0.4) : Theme.of(context).dividerColor,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSafetyFlag)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.danger),
                  SizedBox(width: 6),
                  Text('Please read carefully', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [Flexible(child: bubble)],
      ),
    );
  }
}
