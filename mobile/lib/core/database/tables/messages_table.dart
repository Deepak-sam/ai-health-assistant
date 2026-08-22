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
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
