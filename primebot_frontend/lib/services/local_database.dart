import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local on-device persistence for tasks, class schedule, chat history, and
/// the cached logged-in user profile. Not available on the web (no native
/// filesystem/SQLite bridge in the browser) - callers should check
/// [isAvailable] or simply rely on the empty/no-op fallbacks below.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  bool get isAvailable => !kIsWeb;

  Database? _db;

  Future<Database?> get _database async {
    if (!isAvailable) return null;
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'primebot.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            due_date TEXT NOT NULL,
            priority TEXT NOT NULL,
            category TEXT NOT NULL,
            is_done INTEGER NOT NULL,
            reminder_enabled INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE class_sessions(
            id TEXT PRIMARY KEY,
            course_name TEXT NOT NULL,
            location TEXT NOT NULL,
            weekday INTEGER NOT NULL,
            start_hour INTEGER NOT NULL,
            start_minute INTEGER NOT NULL,
            end_hour INTEGER NOT NULL,
            end_minute INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_sessions(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            text TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            sources TEXT,
            sequence INTEGER NOT NULL,
            FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
          )
        ''');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ---- Tasks ----

  Future<List<Map<String, Object?>>> getTaskRows() async {
    final db = await _database;
    if (db == null) return [];
    return db.query('tasks', orderBy: 'due_date ASC');
  }

  Future<void> upsertTaskRow(Map<String, Object?> row) async {
    final db = await _database;
    if (db == null) return;
    await db.insert('tasks', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTaskRow(String id) async {
    final db = await _database;
    if (db == null) return;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Class sessions ----

  Future<List<Map<String, Object?>>> getClassRows() async {
    final db = await _database;
    if (db == null) return [];
    return db.query('class_sessions');
  }

  Future<void> insertClassRow(Map<String, Object?> row) async {
    final db = await _database;
    if (db == null) return;
    await db.insert('class_sessions', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteClassRow(String id) async {
    final db = await _database;
    if (db == null) return;
    await db.delete('class_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Chat history ----

  Future<List<Map<String, Object?>>> getChatSessionRows() async {
    final db = await _database;
    if (db == null) return [];
    return db.query('chat_sessions', orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, Object?>>> getChatMessageRows(String sessionId) async {
    final db = await _database;
    if (db == null) return [];
    return db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sequence ASC',
    );
  }

  Future<void> upsertChatSessionRow(Map<String, Object?> row) async {
    final db = await _database;
    if (db == null) return;
    await db.insert('chat_sessions', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceChatMessages(String sessionId, List<Map<String, Object?>> rows) async {
    final db = await _database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('chat_messages', where: 'session_id = ?', whereArgs: [sessionId]);
      for (final row in rows) {
        await txn.insert('chat_messages', row);
      }
    });
  }

  Future<void> deleteChatSessionRow(String id) async {
    final db = await _database;
    if (db == null) return;
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [id]);
  }
}
