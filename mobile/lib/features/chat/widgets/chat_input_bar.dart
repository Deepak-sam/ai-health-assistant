import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../nutrition/nutrition_photo_capture_screen.dart';

/// Chat's bottom input bar: a "log food" button (photo/gallery/text-entry
/// options), a mic button (stub — voice input is a Phase 2 item, see TODO
/// below), a text field, and a send button.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend, required this.sending});

  final ValueChanged<String> onSend;
  final bool sending;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  Future<void> _showLogFoodSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Describe what you ate'),
              onTap: () => Navigator.of(context).pop('text'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
      case 'gallery':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NutritionPhotoCaptureScreen(useCamera: choice == 'camera'),
        ));
        break;
      case 'text':
        if (context.mounted) context.push('/nutrition/text-entry');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Log food',
              onPressed: _showLogFoodSheet,
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: 'Voice input (coming soon)',
              // TODO(phase-2): wire up speech-to-text. UI-only stub for now —
              // no audio is captured or sent anywhere.
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice input is coming soon.')),
                );
              },
              icon: const Icon(Icons.mic_none_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Ask about your health…'),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: widget.sending ? null : _send,
              icon: widget.sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
