import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/daos/nutrition_entries_dao.dart';
import '../../core/networking/dio_client.dart';
import '../models/nutrition_models.dart';

/// Talks to `/nutrition/photo` and `/nutrition/text` (API_SPEC.md) and
/// persists confirmed results into `nutrition_entries` — never the source
/// photo (DATABASE_SCHEMA.md §nutrition_entries: "never a photo or photo
/// reference").
class NutritionRepository {
  NutritionRepository({required Dio dio, required NutritionEntriesDao dao})
      : _dio = dio,
        _dao = dao;

  final Dio _dio;
  final NutritionEntriesDao _dao;
  final _uuid = const Uuid();

  /// [imageBytes] must come straight from `image_picker`'s in-memory result
  /// (`XFile.readAsBytes()`) — never from a path written to app-controlled
  /// disk. See features/nutrition/nutrition_photo_capture_screen.dart for
  /// the call site enforcing this.
  Future<NutritionResult> analyzePhoto(Uint8List imageBytes, {required String filename}) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(imageBytes, filename: filename),
    });
    try {
      final response = await _dio.post<Map<String, dynamic>>('/nutrition/photo', data: formData);
      return NutritionResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<NutritionResult> analyzeText(String text, {Map<String, dynamic>? priorEstimate}) async {
    final request = NutritionTextRequest(text: text, priorEstimate: priorEstimate);
    try {
      final response = await _dio.post<Map<String, dynamic>>('/nutrition/text', data: request.toJson());
      return NutritionResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Persists a user-confirmed result (post edit-screen) into
  /// `nutrition_entries`.
  Future<void> saveConfirmedEntry({
    required String userId,
    required NutritionResult result,
    required String source, // 'photo' | 'text' | 'manual'
    DateTime? loggedAt,
  }) async {
    await _dao.insertEntry(db.NutritionEntriesCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      loggedAt: loggedAt ?? DateTime.now(),
      mealName: result.mealName,
      source: source,
      itemsJson: jsonEncode(result.items.map((i) => i.toJson()).toList()),
      totalCalories: result.totalCalories,
      proteinG: result.proteinG,
      carbsG: result.carbsG,
      fatG: result.fatG,
      confidence: Value(source == 'photo' ? result.confidence : null),
      confirmed: const Value(true),
    ));
  }

  Future<List<db.NutritionEntry>> getEntriesForDay({required String userId, required DateTime day}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _dao.getEntriesForDay(userId: userId, dayStart: start, dayEnd: end);
  }

  Stream<List<db.NutritionEntry>> watchEntriesForDay({required String userId, required DateTime day}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _dao.watchEntriesForDay(userId: userId, dayStart: start, dayEnd: end);
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final database = ref.watch(db.appDatabaseProvider);
  return NutritionRepository(dio: ref.watch(dioProvider), dao: database.nutritionEntriesDao);
});
