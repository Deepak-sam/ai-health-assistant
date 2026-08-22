import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/repositories/nutrition_repository.dart';
import 'nutrition_confirm_screen.dart';

/// Picks a photo (camera or gallery) and sends it straight to
/// `POST /nutrition/photo`. Per ARCHITECTURE.md §8/§15 (a hard constraint
/// on this task): the image bytes are held only in memory end-to-end and
/// are never written to a file by this app's own code.
class NutritionPhotoCaptureScreen extends ConsumerStatefulWidget {
  const NutritionPhotoCaptureScreen({super.key, required this.useCamera});

  final bool useCamera;

  @override
  ConsumerState<NutritionPhotoCaptureScreen> createState() => _NutritionPhotoCaptureScreenState();
}

class _NutritionPhotoCaptureScreenState extends ConsumerState<NutritionPhotoCaptureScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickAndAnalyze());
  }

  Future<void> _pickAndAnalyze() async {
    setState(() => _error = null);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: widget.useCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final Uint8List bytes = await file.readAsBytes(); // in-memory only — never written to disk by this app

      final result = await ref.read(nutritionRepositoryProvider).analyzePhoto(bytes, filename: file.name);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/nutrition/confirm', extra: NutritionConfirmArgs(result: result, source: 'photo'));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not analyze that photo. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyzing meal'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _pickAndAnalyze, child: const Text('Try again')),
                  ],
                ),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Estimating calories & macros…'),
                ],
              ),
      ),
    );
  }
}
