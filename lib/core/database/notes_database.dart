import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/note_model.dart';
import '../mock/mock_notes.dart';

class NotesDatabase {
  static const String _dbName = 'voicepen.db';
  static const int _dbVersion = 1;
  static const String tableName = 'notes';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cleaned_content TEXT NOT NULL,
            verbatim_transcript TEXT NOT NULL,
            timestamps_json TEXT NOT NULL,
            audio_path TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            tone TEXT NOT NULL,
            intensity TEXT NOT NULL,
            tags TEXT NOT NULL,
            is_pending INTEGER NOT NULL,
            is_pinned INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Seed initial sample notes on first install
        for (final note in MockNotes.sampleNotes) {
          await db.insert(
            tableName,
            note.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
    );
  }

  Future<List<NoteModel>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'is_pinned DESC, created_at DESC',
    );
    return maps.map((map) => NoteModel.fromMap(map)).toList();
  }

  Future<void> insertNote(NoteModel note) async {
    final db = await database;
    await db.insert(
      tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(NoteModel note) async {
    final db = await database;
    await db.update(
      tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTitle(String id, String newTitle) async {
    final db = await database;
    await db.update(
      tableName,
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePinStatus(String id, bool isPinned) async {
    final db = await database;
    await db.update(
      tableName,
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTone(String id, String newTone) async {
    final db = await database;
    await db.update(
      tableName,
      {'tone': newTone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllNotes() async {
    final db = await database;
    await db.delete(tableName);
  }

  Future<void> resetMockNotes() async {
    final db = await database;
    await db.delete(tableName);
    for (final note in MockNotes.sampleNotes) {
      await db.insert(
        tableName,
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
