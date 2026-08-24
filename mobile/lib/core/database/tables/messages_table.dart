import 'package:drift/drift.dart';

/// DATABASE_SCHEMA.md §messages.
class Messages extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();
  TextColumn get cardJson => text().named('card_json').nullable()();
  // The context bundle sent to POST /chat for this turn, kept for
  // debugging/auditability — never sent anywhere itself.
  TextColumn get relatedQueryJson => text().named('related_query_json').nullable()();
  // API_SPEC.md `/chat` response `safety_flag` (e.g. "seek_medical_attention"),
  // persisted so a safety-flagged reply still renders distinctly when a past
  // conversation is reopened from History, not just right after sending.
  TextColumn get safetyFlag => text().named('safety_flag').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
