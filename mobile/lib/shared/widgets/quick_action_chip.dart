import 'package:flutter/material.dart';

/// A tappable suggestion chip, e.g. "How did I sleep?" / "Should I train
/// today?" — no gamification styling (no streak flames, no badges), just a
/// calm rounded chip matching the input bar's radius.
class QuickActionChip extends StatelessWidget {
  const QuickActionChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
