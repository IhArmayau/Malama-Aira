import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalRagDatabase {
  static final LocalRagDatabase instance = LocalRagDatabase._init();
  static Database? _database;

  LocalRagDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('malama_aira_rag.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create tables for RAG documents, chat sessions, or embeddings
    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertMessage(String role, String content) async {
    final db = await instance.database;
    return await db.insert('chat_history', {
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    final db = await instance.database;
    return await db.query('chat_history', orderBy: 'id ASC');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}